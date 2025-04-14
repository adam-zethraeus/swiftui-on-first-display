import Foundation
import OnLive
import SwiftUI
import os

struct App: SwiftUI.App {

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        TestView()
      }
    }
  }
}

@Observable
final class CancelCounter {
  var cancels: Int = 0
}

struct TestView: View {
  @State var cancelCounter: CancelCounter = .init()
  @State var navigation: Bool? = nil
  @State var present: Bool = false
  @Environment(\.dismiss) var dismiss
  @State var id: UUID = UUID()
  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack {
          Text("Resize this view")
          Spacer()
          CountView(cancelCounter: cancelCounter)
          CountView(cancelCounter: cancelCounter)
          CountView(cancelCounter: cancelCounter)
          Spacer()
          Text("all whileLive cancels: **\(cancelCounter.cancels)**")
        }
      }
      .sheet(isPresented: $present) {
        VStack {
          CountView(cancelCounter: cancelCounter)

          Button {
            present = false
          } label: {
            Text("close")
          }
        }
      }
    }

      .toolbar {
        ToolbarItemGroup {
          HStack {
            Button("present") {
              present = true
            }
          }.background(Pastel.hash(from: id))
        }
      }
  }
}

struct CountView: View {
  @State var id: UUID = .init()
  var cancelCounter: CancelCounter
  @State var ofdCount = 0
  @State var oaCount = 0
  @State var tCount = 0
  @State var tcCount = 0
  @State var aofdCount = 0
  @State var aofdcCount = 0
  var body: some View {
    VStack {
      Text("onAppear \t\t\t(start:**\(oaCount)**)")
        .onAppear {
          oaCount += 1
        }
      Text("task \t\t(start:**\(tCount)**, cancel:**\(tcCount)**)")
        .task {
          tCount += 1
          do {
            try await Task.sleep(for: .seconds(9999999))
          } catch {
            tcCount += 1
          }
        }

      VStack {
        Text("onLive: \t\t\t\t(start:**\(ofdCount)**)")
          .onLive {
            ofdCount += 1
          }
        Text("whileLive \t(start:**\(aofdCount)**, cancel:**\(aofdcCount)**)")
          .whileLive {
            aofdCount += 1
            try? await Task.sleep(for: .seconds(9999999))
            cancelCounter.cancels += 1
            aofdcCount += 1
          }
      }.border(.black)

    }
    .background(Pastel.hash(from: id))
    .border(.black)
    .padding(.bottom)
  }
}

public enum Pastel {

  /// Generate a stable pastel color hash for an entity.
  /// Like the `Hashable` `hash(into:)` hash value which it uses, the pastel
  /// is only stable during a session as `Hasher` uses a random seed.
  ///
  /// > ## Wikipedia:
  /// > 'Pastels belong to a pale family of colors, which, when described in the HSV color space,
  /// have high value and low saturation.'*
  /// HSB' and 'HSV' are different names for the same color spaces defined by:
  /// > * Hue: the tint of the color.
  /// > * Saturation: the distance of the color from a pure grey of the same Brightness.
  /// > * Brightness/Value: How 'lit up' the color is. 0 = Black. 1 = 'Fully visible'.
  ///
  /// We, however, define 'Pastel' as:
  /// > * Any hue...
  /// > * ...of low saturation [0.05, 0.4]...
  /// > * ...and moderate to high brightness [0.6, 1.0].
  ///
  /// Generating a random number from zero to one in the HSB color space would not
  /// appear 'random' to humans. It would appear to show more of certain colors as
  /// they are 'stretched' in the space.
  /// See: https://en.wikipedia.org/wiki/HSL_and_HSV
  ///
  /// The RGB color space is also not uniform across human perception. We would
  /// prefer a random base color in the CGColorSpace.genericLab color space which
  /// is modeled to be uniform across human perception.
  /// However the L*a*b* color space has invalid regions when sampled naively — so
  /// randomization is harder.
  ///
  /// And we stick to RGB.
  public static func hash(from item: some Hashable) -> Color {
    let hash = UInt64(abs(item.hashValue))

    let reader = ColorReader(
      red: round(CGFloat((hash & 0xFF0000) >> 16) / 255.0),
      green: round(CGFloat((hash & 0x00FF00) >> 8) / 255.0),
      blue: round(CGFloat(hash & 0x0000FF) / 255.0)
    )

    let pastelHue = reader.hsba.hue
    let pastelSaturation = 0.05 + (reader.hsba.saturation * 0.35)
    let pastelBrightness = 0.6 + (reader.hsba.brightness * 0.4)

    return Color(
      hue: pastelHue,
      saturation: pastelSaturation,
      brightness: pastelBrightness
    )
  }

}

/// Convertible to ``ColorReader``
public protocol ColorReaderConvertible {
  var colorReader: ColorReader { get }
}

public struct ColorReader: Hashable, Sendable {

  public init<Intensity: BinaryFloatingPoint>(
    red: Intensity,
    green: Intensity,
    blue: Intensity,
    alpha: Intensity = 1.0
  ) {
    self.storage = .init(
      red: red.clamped,
      green: green.clamped,
      blue: blue.clamped,
      alpha: alpha.clamped
    )
  }

  public init(_ convertible: some ColorReaderConvertible) {
    self = convertible.colorReader
  }

  // MARK: Public

  public var description: String {
    rgba.hexString
  }

  // MARK: Private

  private let storage: RGBA

}

// MARK: - native color type bridging

#if canImport(UIKit)
  import UIKit
  public typealias NativeColor = UIColor
  extension ColorReader {

    // MARK: Lifecycle

    public init(_ nativeColorReader: NativeColor) {
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      nativeColorReader.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

      self.init(
        red: red,
        green: green,
        blue: blue,
        alpha: alpha
      )
    }

    // MARK: Public

    public var uiColor: UIColor { nativeColor }

    // MARK: Internal

    var nativeColor: NativeColor {
      NativeColor(
        red: storage.red,
        green: storage.green,
        blue: storage.blue,
        alpha: storage.alpha
      )
    }
  }

#elseif canImport(AppKit)
  import AppKit
  public typealias NativeColor = NSColor
  extension ColorReader {

    // MARK: Lifecycle

    public init(_ nativeColorReader: NativeColor) {
      self.init(
        red: nativeColorReader.redComponent,
        green: nativeColorReader.greenComponent,
        blue: nativeColorReader.blueComponent,
        alpha: nativeColorReader.alphaComponent
      )
    }

    // MARK: Public

    public var nsColor: NSColor { nativeColor }

    // MARK: Internal

    var nativeColor: NativeColor {
      NativeColor(red: storage.red, green: storage.green, blue: storage.blue, alpha: storage.alpha)
    }
  }
#endif

#if canImport(SwiftUI)
  import SwiftUI
  extension ColorReader {

    // MARK: Lifecycle

    public init(_ color: Color) {
      self.init(NativeColor(color))
    }

    // MARK: Public

    public var swiftUI: Color {
      get {
        Color(nativeColor)
      }
      set {
        self = .init(NativeColor(newValue))
      }
    }
  }
#endif

// MARK: - NativeColorReaderConvertible

private protocol NativeColorReaderConvertible {
  var nativeColor: NativeColor { get }
}

// MARK: - color representations
extension ColorReader {
  public struct RGBA: Hashable, Sendable, ColorReaderConvertible,
    NativeColorReaderConvertible
  {

    // MARK: Lifecycle

    public init(RGBAHex: UInt32) {
      let red = Double((RGBAHex & 0xFF00_0000) >> 24) / 255.0
      let green = Double((RGBAHex & 0xFF0000) >> 16) / 255.0
      let blue = Double((RGBAHex & 0xFF00) >> 8) / 255.0
      let alpha = Double((RGBAHex & 0xFF) >> 0) / 255.0
      self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    public init(RGBHex: UInt32, alpha: Double = 1.0) {
      let red = Double((RGBHex & 0xFF0000) >> 16) / 255.0
      let green = Double((RGBHex & 0xFF00) >> 8) / 255.0
      let blue = Double((RGBHex & 0xFF) >> 0) / 255.0
      self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    public init<Intensity: BinaryFloatingPoint>(
      red: Intensity,
      green: Intensity,
      blue: Intensity,
      alpha: Intensity
    ) {
      self.red = red.clamped
      self.blue = blue.clamped
      self.green = green.clamped
      self.alpha = alpha.clamped
    }

    // MARK: Public

    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public var hexString: String {
      [red, green, blue, alpha]
        .map { channelProportion in
          String(
            format: "%02lx",
            Int(round(channelProportion * 255.0))
          )
        }
        .reduce("#", +)
    }

    public var colorReader: ColorReader {
      .init(red: red, green: green, blue: blue, alpha: alpha)
    }

    public var description: String {
      "RGBA(\(red.decimal), \(green.decimal), \(blue.decimal), \(alpha.decimal))"
    }

    // MARK: Internal

    var nativeColor: NativeColor {
      NativeColor(red: red, green: green, blue: blue, alpha: alpha)
    }

  }

  public struct CMYKA: Hashable, Sendable, ColorReaderConvertible,
    NativeColorReaderConvertible
  {

    // MARK: Lifecycle

    public init<Intensity: BinaryFloatingPoint>(
      cyan: Intensity,
      magenta: Intensity,
      yellow: Intensity,
      black: Intensity,
      alpha: Intensity
    ) {
      self.cyan = cyan.clamped
      self.magenta = magenta.clamped
      self.yellow = yellow.clamped
      self.black = black.clamped
      self.alpha = alpha.clamped
    }

    // MARK: Public

    public var cyan: Double
    public var magenta: Double
    public var yellow: Double
    public var black: Double
    public var alpha: Double

    public var colorReader: ColorReader {
      ColorReader(nativeColor)
    }

    public var description: String {
      "CMYKA(\(cyan.decimal), \(magenta.decimal), \(yellow.decimal), \(black.decimal), \(alpha.decimal))"
    }

    // MARK: Internal

    var nativeColor: NativeColor {
      let rgba = rgba
      return NativeColor(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
    }

    var rgba: RGBA {
      let r = (1.0 - cyan) * (1.0 - black)
      let g = (1.0 - magenta) * (1.0 - black)
      let b = (1.0 - yellow) * (1.0 - black)
      return .init(red: r, green: g, blue: b, alpha: alpha)
    }

  }

  public struct HSBA: Hashable, Sendable, ColorReaderConvertible,
    NativeColorReaderConvertible
  {

    // MARK: Lifecycle

    public init<Intensity: BinaryFloatingPoint>(
      hue: Intensity,
      saturation: Intensity,
      brightness: Intensity,
      alpha: Intensity
    ) {
      self.hue = hue.clamped
      self.saturation = saturation.clamped
      self.brightness = brightness.clamped
      self.alpha = alpha.clamped
    }

    // MARK: Public

    public var hue: Double
    public var saturation: Double
    public var brightness: Double
    public var alpha: Double

    public var colorReader: ColorReader {
      ColorReader(nativeColor)
    }

    public var description: String {
      "HSBA(\(hue.decimal), \(saturation.decimal), \(brightness.decimal), \(alpha.decimal))"
    }

    // MARK: Internal

    var nativeColor: NativeColor {
      NativeColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }

  }
}

extension ColorReader {

  /// Red, Green, Blue, Alpha
  public var rgba: RGBA {
    storage
  }

  #if canImport(UIKit) || canImport(AppKit)
    /// Hue, Saturation, Brightness, Alpha
    public var hsba: HSBA {
      #if canImport(UIKit)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nativeColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return HSBA(hue: h, saturation: s, brightness: b, alpha: a)
      #elseif canImport(AppKit)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nativeColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return HSBA(hue: h, saturation: s, brightness: b, alpha: a)
      #endif
    }
  #endif

  #if canImport(UIKit) || canImport(AppKit)
    /// Cyan, Magenta, Black, Alpha
    public var cmyka: CMYKA {
      #if canImport(UIKit)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nativeColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        let k = 1.0 - max(r, g, b)
        var c = (1.0 - r - k) / (1.0 - k)
        var m = (1.0 - g - k) / (1.0 - k)
        var y = (1.0 - b - k) / (1.0 - k)

        if c.isNaN {
          c = 0.0
        }
        if m.isNaN {
          m = 0.0
        }
        if y.isNaN {
          y = 0.0
        }
        return CMYKA(cyan: c, magenta: m, yellow: y, black: k, alpha: a)
      #elseif canImport(AppKit)
        var c: CGFloat = 0
        var m: CGFloat = 0
        var y: CGFloat = 0
        var k: CGFloat = 0
        var a: CGFloat = 0
        nativeColor.getCyan(&c, magenta: &m, yellow: &y, black: &k, alpha: &a)

        return CMYKA(cyan: c, magenta: m, yellow: y, black: k, alpha: a)
      #endif
    }
  #endif
}

extension ColorReader {
  public func saturation(_ multiple: Double) -> ColorReader {
    var hsba = hsba
    hsba.saturation = (hsba.saturation * multiple).clamped
    return hsba.colorReader
  }

  public func brightness(_ multiple: Double) -> ColorReader {
    var hsba = hsba
    hsba.brightness = (hsba.brightness * multiple).clamped
    return hsba.colorReader
  }

  public func hue(_ multiple: Double) -> ColorReader {
    var hsba = hsba
    hsba.hue = (hsba.hue * multiple).clamped
    return hsba.colorReader
  }
}

// MARK: - private convenience extensions

extension BinaryFloatingPoint {
  fileprivate var clamped: Double { max(min(Double(self), 1.0), 0.0) }
}

extension Double {
  fileprivate var decimal: String {
    String(format: "%.3f", self)
  }
}

App.main()
