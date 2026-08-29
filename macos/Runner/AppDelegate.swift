import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var menuBarChannel: FlutterMethodChannel?
  private var menuBarPanelController: MenuBarPanelController?

  func configureMenuBar(with flutterViewController: FlutterViewController, mainWindow: NSWindow) {
    guard menuBarPanelController == nil else { return }

    let channel = FlutterMethodChannel(
      name: "gpu_monitor/menu_bar",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    let panelController = MenuBarPanelController(channel: channel, mainWindow: mainWindow)
    channel.setMethodCallHandler { [weak panelController] call, result in
      switch call.method {
      case "updateSnapshot":
        panelController?.updateSnapshot(call.arguments)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    menuBarChannel = channel
    menuBarPanelController = panelController
    panelController.start()
  }

  override func applicationWillTerminate(_ notification: Notification) {
    menuBarPanelController?.stop()
    menuBarPanelController = nil
    menuBarChannel = nil
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in sender.windows {
        window.makeKeyAndOrderFront(self)
      }
      sender.activate(ignoringOtherApps: true)
    }
    return true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
