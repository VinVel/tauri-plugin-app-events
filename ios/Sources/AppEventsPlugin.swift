/*
 * Copyright (c) 2024 wtto00
 * Copyright (c) 2026 VinVel
 * SPDX-License-Identifier: MIT
 */

import OSLog
import SwiftRs
import Tauri
import UIKit
import WebKit

private let log = OSLog(subsystem: "tauri-plugin-app-events", category: "plugin")

private final class SetEventHandlerArgs: Decodable {
  let handler: Channel
}

final class AppEventsPlugin: Plugin, UIGestureRecognizerDelegate {
  private var webview: WKWebView? = nil
  private var backGestureRecognizer: UIScreenEdgePanGestureRecognizer? = nil
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
    if let recognizer = backGestureRecognizer {
      webview?.removeGestureRecognizer(recognizer)
    }
    NotificationCenter.default.removeObserver(self)
  }

  override func load(webview: WKWebView) {
    self.webview = webview

    if let recognizer = backGestureRecognizer {
      webview.removeGestureRecognizer(recognizer)
    }

    let recognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleBackGesture))
    recognizer.edges = .left
    recognizer.cancelsTouchesInView = false
    recognizer.delegate = self
    webview.addGestureRecognizer(recognizer)
    backGestureRecognizer = recognizer
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    return true
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

  @objc
  private func handleBackGesture(_ recognizer: UIScreenEdgePanGestureRecognizer) {
    guard recognizer.state == .ended else {
      return
    }

    os_log(.debug, log: log, "Back gesture")
    var event = JSObject()
    event["canGoBack"] = webview?.canGoBack ?? false
    trigger("back-key-down", data: event)
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
