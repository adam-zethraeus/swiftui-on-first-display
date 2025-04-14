import SwiftUI
import os

extension View {
  public func onLive(operation: @escaping () -> Void) -> some View {
    self.modifier(OnFirstDisplayViewModifier(action: operation))
  }

  public func whileLive(operation: @escaping @MainActor () async -> Void) -> some View {
    self.modifier(AsyncOnFirstDisplayViewModifier(action: operation))
  }
}

@MainActor
struct OnFirstDisplayViewModifier: ViewModifier {

  @State var count: Int = 0
  let action: () -> Void

  func body(content: Content) -> some View {
    content.onAppear {
      if count == 0 {
        count += 1
        action()
      }
    }
  }
}


@Observable
final class DeinitChecker {
  init(task: Task<Void, Never>) {
    self.task = task
  }
  init() {}
  var task: Task<Void, Never>?
  deinit {
    task?.cancel()
  }
}


@MainActor
struct AsyncOnFirstDisplayViewModifier: ViewModifier {

  let action: () async -> Void
  @State var count: Int = 0

  @State var task: DeinitChecker = .init()



  func body(content: Content) -> some View {
    content
      .task {
        if count == 0 {
          count += 1
          task.task = Task { [action] in
            await action()
          }
        }

      }
  }
}

