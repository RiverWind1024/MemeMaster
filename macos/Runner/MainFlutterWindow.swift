import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    
    // 设置默认窗口大小 (1280x720)，与手机屏幕比例相近
    let defaultSize = NSSize(width: 1280, height: 720)
    self.setFrame(NSRect(origin: windowFrame.origin, size: defaultSize), display: true)

    // 设置最小窗口尺寸，避免 UI 缩放过小导致无法使用
    self.minSize = NSSize(width: 800, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
