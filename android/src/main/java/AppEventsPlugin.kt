package net.velcore.tauri_plugin_app_events

import android.app.Activity
import android.webkit.WebView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import app.tauri.Logger
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Channel
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin

@InvokeArg
class SetEventHandlerArgs {
    lateinit var handler: Channel
}

/*
 * Copyright (c) 2026 VinVel
 * SPDX-License-Identifier: MIT
 */
@TauriPlugin
class AppEventsPlugin(private val activity: Activity) : Plugin(activity) {
    private val logTag = "TAURI_PLUGIN_APP_EVENTS"
    private val backKeyDownEvent = "back-key-down"

    private var webView: WebView? = null
    private var resumeChannel: Channel? = null
    private var pauseChannel: Channel? = null

    init {
        val callback =
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    val currentWebView = webView

                    if (!hasListener(backKeyDownEvent)) {
                        if (currentWebView?.canGoBack() == true) {
                            currentWebView.goBack()
                        } else {
                            isEnabled = false
                            activity.onBackPressed()
                            isEnabled = true
                        }
                        return
                    }

                    val event =
                        JSObject().apply {
                            put("canGoBack", currentWebView?.canGoBack() ?: false)
                        }
                    trigger(backKeyDownEvent, event)
                }
            }

        (activity as AppCompatActivity).onBackPressedDispatcher.addCallback(activity, callback)
    }

    override fun load(webView: WebView) {
        this.webView = webView
    }

/*
 * Copyright (c) 2024 wtto00
 * Copyright (c) 2026 VinVel
 * SPDX-License-Identifier: MIT
 */
    override fun onResume() {
        Logger.debug(logTag, "onResume")
        val event = JSObject()
        trigger("resume", event)
        resumeChannel?.send(event)
        super.onResume()
    }

    @Command
    fun setResumeHandler(invoke: Invoke) {
        Logger.debug(logTag, "setResumeHandler")
        val args = invoke.parseArgs(SetEventHandlerArgs::class.java)
        resumeChannel = args.handler
        invoke.resolve()
    }

    override fun onPause() {
        Logger.debug(logTag, "onPause")
        val event = JSObject()
        trigger("pause", event)
        pauseChannel?.send(event)
        super.onPause()
    }

    @Command
    fun setPauseHandler(invoke: Invoke) {
        Logger.debug(logTag, "setPauseHandler")
        val args = invoke.parseArgs(SetEventHandlerArgs::class.java)
        pauseChannel = args.handler
        invoke.resolve()
    }
}
