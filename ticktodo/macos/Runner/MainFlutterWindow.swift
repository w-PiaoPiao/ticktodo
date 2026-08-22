import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // macOS HIG：约束最小可用窗口尺寸，初始尺寸适合侧边栏布局
    self.minSize = NSSize(width: 900, height: 600)
    if windowFrame.width < 1024 || windowFrame.height < 700 {
      self.setFrame(NSRect(x: 0, y: 0, width: 1100, height: 760), display: true)
      self.center()
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
