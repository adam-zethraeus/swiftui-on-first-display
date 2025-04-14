# `onLive` — SwiftUI lifecycle operators which fire exactly once.  

Usable lifecycle guarantees for SwiftUI.
   
`onAppear` -> `onLive`  
`task` -> `whileLive`

## Why?

SwiftUI's standard view lifecycle methods are sometimes called repeatedly — making binding a behavior
to your view's lifecycle much more complicated.

```swift
.task {
    for await payload in createWebsocketConnection() {
        // This subscription can be created multiple times.
    }
}
```

This demo shows `onAppear`, `task`, and `task`'s cancellation behavior called repeatedly (within a LazyVStack — the simplest reproduction case). 

Notice that:
* `onLive` (replacing `onAppear`) and `whileLive` (replacing `task`) are called exactly once.
* `whileLive`'s long running behaviors (like subscriptions in `task`) are cancelled once, after permanent view removal.

![](https://github.com/user-attachments/assets/3b7e370c-955f-435f-924b-ae646928a2ab)

This demo can be run from the repo with `swift run Example`
