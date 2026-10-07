import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // The ground behind Flutter's first frame: Android's `splash_background`,
    // light and dark, so the window does not open on a white or black sheet
    // before the lotus loader is drawn.
    flutterViewController.backgroundColor = NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        ? NSColor(srgbRed: 0x24 / 255.0, green: 0x1C / 255.0, blue: 0x14 / 255.0, alpha: 1)
        : NSColor(srgbRed: 0xFD / 255.0, green: 0xF7 / 255.0, blue: 0xEA / 255.0, alpha: 1)
    }
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
