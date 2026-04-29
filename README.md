# Tauri Plugin app-events

A plugin for [tauri@v2](https://v2.tauri.app/zh-cn/) to listen some events on iOS and Android.

## Fork Notice

This repository is a fork of the original MIT-licensed `tauri-plugin-app-events` project. The original copyright notice is retained in [LICENSE](./LICENSE).

## Platform Supported

| Platform | Supported |
| -------- | :-------: |
| Linux    |    ❌     |
| Windows  |    ❌     |
| macOS    |    ❌     |
| Android  |    ✅     |
| iOS      |    ✅     |

For desktop platforms, please use [@tauri-apps/api/event](https://v2.tauri.app/reference/javascript/api/namespaceevent/) or the JavaScript method [keydown event](https://developer.mozilla.org/zh-CN/docs/Web/API/Element/keydown_event).

## Setup

Install the `app-events` plugin to get started.

1. Add the Rust plugin as a local path dependency in your app's `src-tauri/Cargo.toml`:

   ```toml
   [target.'cfg(any(target_os = "android", target_os = "ios"))'.dependencies]
   tauri-plugin-app-events = { path = "../plugins/tauri-plugin-app-events" }
   ```

   Adjust the path so it points from your app's `src-tauri` directory to this plugin directory.

1. Modify `lib.rs` to initialize the plugin:

   ```diff
    #[cfg_attr(mobile, tauri::mobile_entry_point)]
    pub fn run() {
        tauri::Builder::default()
            .setup(|app| {
   +            #[cfg(mobile)]
   +            app.handle().plugin(tauri_plugin_app_events::init())?;
                Ok(())
            })
            .run(tauri::generate_context!())
            .expect("error while running tauri application");
    }
   ```

1. Modify `src-tauri/capabilities/mobile.json` to Allow the frontend to execute the `registerListener` command.

   ```diff
    {
      "$schema": "../gen/schemas/mobile-schema.json",
      "identifier": "mobile",
      "description": "Capability for the main window on mobile platform",
      "windows": ["main"],
      "permissions": [
   +    "app-events:default"
      ],
      "platforms": ["android", "iOS"]
    }
   ```

1. Build the JavaScript guest bindings from the plugin directory:

   ```shell
   bun run build
   ```

1. Install the JavaScript guest bindings as a local path dependency in your app:

   ```shell
   bun add ./plugins/tauri-plugin-app-events
   ```

   Adjust the path so it points from your app's frontend package directory to this plugin directory. The package name remains `tauri-plugin-app-events-api`.

### Optional Android Hardware Key Bridge

Back navigation does not need host app changes. Android system back and gesture back are handled by the plugin.

Other Android hardware keys, such as menu, search, volume, or arbitrary key codes, are not exposed through Tauri's Android plugin lifecycle hooks. To use those optional APIs, add a host bridge in your generated `MainActivity.kt`:

```kotlin
package your.app.package

import android.view.KeyEvent
import android.webkit.WebView

class MainActivity : TauriActivity() {
  private var webView: WebView? = null

  override fun onWebViewCreate(webView: WebView) {
    this.webView = webView
  }

  private val keyEventMap = mapOf(
    KeyEvent.KEYCODE_MENU to "menu",
    KeyEvent.KEYCODE_SEARCH to "search",
    KeyEvent.KEYCODE_VOLUME_DOWN to "volume_down",
    KeyEvent.KEYCODE_VOLUME_UP to "volume_up"
  )

  override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
    val callbackName = keyEventMap[keyCode]
    val script =
      if (callbackName != null) {
        "window.__tauri_android_on_${callbackName}_key_down__()"
      } else {
        "window.__tauri_android_on_key_down__($keyCode)"
      }

    webView?.evaluateJavascript(
      """
        try {
          $script
        } catch (_) {
          true
        }
      """.trimIndent()
    ) { result ->
      if (result != "false") {
        super.onKeyDown(keyCode, event)
      }
    }

    return true
  }
}
```

## Usage

### Api Support

| Api                 | Android | iOS |
| ------------------- | :-----: | :-: |
| onResume            |   ✅    | ✅  |
| onPause             |   ✅    | ✅  |
| onBackKeyDown       |   ✅    | ✅  |
| onMenuKeyDown       | Bridge  | ❌  |
| onSearchKeyDown     | Bridge  | ❌  |
| onVolumeDownKeyDown | Bridge  | ❌  |
| onVolumeUpKeyDown   | Bridge  | ❌  |
| onKeyDown           | Bridge  | ❌  |

### Import Apis

```js
import {
  onResume,
  onPause,
  onBackKeyDown,
  onMenuKeyDown,
  onSearchKeyDown,
  onVolumeDownKeyDown,
  onVolumeUpKeyDown,
  onKeyDown,
} from "tauri-plugin-app-events-api";
```

### Note

All listener APIs only support a single callback, so repeated calls will cause the previous listener to be overridden.

Therefore, if you want to cancel the listener, you can pass an empty parameter in functions like `onResume()`.

Back navigation is implemented entirely inside this plugin. On Android, system back button presses and gesture back both emit `onBackKeyDown`. On iOS, a left-edge swipe gesture emits `onBackKeyDown`.

When an Android `onBackKeyDown` listener is registered, the plugin consumes Android back presses and emits the event to JavaScript. When no listener is registered, the plugin preserves the default behavior: navigate back in the WebView when possible, otherwise let the Activity handle the back press.

The menu, search, volume, and arbitrary key APIs only work when the optional Android hardware key bridge is installed in the host Activity. If those callbacks return `false`, the host bridge prevents the default Android key behavior. If they return any other value or no value, the default behavior continues.

### onResume

The `resume` event fires when the system pulls the application out from the background.

```js
onResume(() => {
  console.log("App resume");
});
```

### Calling in Rust

```rust
tauri::Builder::default()
    .invoke_handler(tauri::generate_handler![greet])
    .setup(|app| {
        #[cfg(mobile)]
        {
            let app_handle = app.handle();
            app_handle.plugin(tauri_plugin_app_events::init())?;
            let app_cloned = app_handle.clone();
            app_handle
                .app_events()
                .set_resume_handler(Channel::new(move |_| {
                    // The app has returned to the foreground.
                    app_cloned.emit("js-log", "set_resume_handler")?;
                    Ok(())
                }))?;
            let app_cloned = app_handle.clone();
            app_handle
                .app_events()
                .set_pause_handler(Channel::new(move |_| {
                    // The app has switched to the background.
                    app_cloned.emit("js-log", "set_pause_handler")?;
                    Ok(())
                }))?;
        }
        Ok(())
    })
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
```

> Note that executing `println!("some log")` in the handler callback in Rust will have no effect.

### onPause

The `pause` event fires when the system puts the application into the background, typically when the user switches to a different application.

```js
onPause(() => {
  console.log("App pause");
});
```

In `Rust`, refer to the instructions mentioned above in `onResume`.

### onBackKeyDown

The event fires when the user presses the back button or uses gesture back on Android, or when the user performs a left-edge swipe on iOS.

```js
onBackKeyDown((event) => {
  console.log("Back navigation triggered", event.canGoBack);
});
```

### onMenuKeyDown

Android host bridge only. The event fires when the user presses the menu button.

```js
onMenuKeyDown(() => {
  console.log("Menu key triggered");
  return false;
});
```

### onSearchKeyDown

Android host bridge only. The event fires when the user presses the search button.

```js
onSearchKeyDown(() => {
  console.log("Search key triggered");
  return false;
});
```

### onVolumeDownKeyDown

Android host bridge only. The event fires when the user presses the volume down button.

```js
onVolumeDownKeyDown(() => {
  console.log("Volume down key triggered");
  return false;
});
```

### onVolumeUpKeyDown

Android host bridge only. The event fires when the user presses the volume up button.

```js
onVolumeUpKeyDown(() => {
  console.log("Volume up key triggered");
  return false;
});
```

### onKeyDown

Android host bridge only. Use this for key codes that do not have a dedicated helper.

```js
onKeyDown((keyCode) => {
  console.log(`Key ${keyCode} triggered`);
  return false;
});
```

## [Permission description](./permissions/autogenerated/reference.md)
