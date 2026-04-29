import OSLog
import SwiftRs
import Tauri
import UIKit

private let log = OSLog(subsystem: "tauri-plugin-app-events", category: "plugin")

private final class SetEventHandlerArgs: Decodable {
  let handler: Channel
}

final class AppEventsPlugin: Plugin {
  private var resumeChannel: Channel? = nil
  private var pauseChannel: Channel? = nil

  override init() {
    super.init()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc
  private func applicationDidBecomeActive(notification: NSNotification) {
    os_log(.debug, log: log, "Application did become active")
    let event = JSObject()
    trigger("resume", data: event)
    resumeChannel?.send(event)
  }

  @objc
  private func applicationDidEnterBackground(notification: NSNotification) {
    os_log(.debug, log: log, "Application did enter background")
    let event = JSObject()
    trigger("pause", data: event)
    pauseChannel?.send(event)
  }

  @objc public func setResumeHandler(_ invoke: Invoke) throws {
    os_log(.debug, log: log, "setResumeHandler")
    let args = try invoke.parseArgs(SetEventHandlerArgs.self)
    resumeChannel = args.handler
    invoke.resolve()
  }

  @objc public func setPauseHandler(_ invoke: Invoke) throws {
    os_log(.debug, log: log, "setPauseHandler")
    let args = try invoke.parseArgs(SetEventHandlerArgs.self)
    pauseChannel = args.handler
    invoke.resolve()
  }
}

@_cdecl("init_plugin_app_events")
func initPlugin() -> Plugin {
  return AppEventsPlugin()
}
