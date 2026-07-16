import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    
    // 禁用窗口状态恢复，避免 macOS 记住上次窗口大小
    self.isRestorable = false

    // 设置默认窗口大小 (720x1280)，竖屏比例
    let defaultSize = NSSize(width: 720, height: 1280)
    self.setFrame(NSRect(origin: windowFrame.origin, size: defaultSize), display: true)

    // 设置最小窗口尺寸，避免 UI 缩放过小导致无法使用
    self.minSize = NSSize(width: 400, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // 窗口显示后再次强制设置大小，确保不会被 macOS 覆盖
    DispatchQueue.main.async {
      let defaultSize = NSSize(width: 720, height: 1280)
      self.setFrame(NSRect(origin: self.frame.origin, size: defaultSize), display: true)
    }
  }
}
