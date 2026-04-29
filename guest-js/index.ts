/**
 * Copyright (c) 2024 wtto00
 * Copyright (c) 2026 VinVel
 * SPDX-License-Identifier: MIT
 */

import { addPluginListener } from "@tauri-apps/api/core";
import type { PluginListener } from "@tauri-apps/api/core";

/**
 * @returns Whether to allow default host behavior.
 * - true or undefined: allow default behavior
 * - false: prevent default behavior
 */
export type KeyDownCallback = (() => boolean) | (() => void);

export type KeyDownCodeCallback =
  | ((keyCode: number) => boolean)
  | ((keyCode: number) => void);

export interface BackNavigationEvent {
  canGoBack: boolean;
}

declare global {
  interface Window {
    __tauri_android_on_menu_key_down__: KeyDownCallback;
    __tauri_android_on_search_key_down__: KeyDownCallback;
    __tauri_android_on_volume_down_key_down__: KeyDownCallback;
    __tauri_android_on_volume_up_key_down__: KeyDownCallback;
    __tauri_android_on_key_down__: KeyDownCodeCallback;
  }
}

let _resumeCallback: () => void;
function resumeCallback() {
  _resumeCallback?.();
}
export function onResume(callback: () => void = () => {}) {
  if (!_resumeCallback) {
    addPluginListener("app-events", "resume", resumeCallback);
  }
  _resumeCallback = callback;
}

let _pauseCallback: () => void;
function pauseCallback() {
  _pauseCallback?.();
}
export function onPause(callback: () => void = () => {}) {
  if (!_pauseCallback) {
    addPluginListener("app-events", "pause", pauseCallback);
  }
  _pauseCallback = callback;
}

let _backKeyDownCallback: ((event: BackNavigationEvent) => void) | undefined;
let _backKeyDownListener: Promise<PluginListener> | undefined;
function backKeyDownCallback(event: { payload: BackNavigationEvent }) {
  _backKeyDownCallback?.(event.payload);
}

/** Android and iOS */
export async function onBackKeyDown(callback?: (event: BackNavigationEvent) => void) {
  if (!callback) {
    _backKeyDownCallback = undefined;
    const listener = await _backKeyDownListener;
    await listener?.unregister();
    _backKeyDownListener = undefined;
    return;
  }

  if (!_backKeyDownListener) {
    _backKeyDownListener = addPluginListener(
      "app-events",
      "back-key-down",
      backKeyDownCallback,
    );
  }
  _backKeyDownCallback = callback;
}

window.__tauri_android_on_menu_key_down__ = () => {};
/** Android host bridge only */
export function onMenuKeyDown(callback: KeyDownCallback = () => {}) {
  window.__tauri_android_on_menu_key_down__ = callback;
}

window.__tauri_android_on_search_key_down__ = () => {};
/** Android host bridge only */
export function onSearchKeyDown(callback: KeyDownCallback = () => {}) {
  window.__tauri_android_on_search_key_down__ = callback;
}

window.__tauri_android_on_volume_down_key_down__ = () => {};
/** Android host bridge only */
export function onVolumeDownKeyDown(callback: KeyDownCallback = () => {}) {
  window.__tauri_android_on_volume_down_key_down__ = callback;
}

window.__tauri_android_on_volume_up_key_down__ = () => {};
/** Android host bridge only */
export function onVolumeUpKeyDown(callback: KeyDownCallback = () => {}) {
  window.__tauri_android_on_volume_up_key_down__ = callback;
}

window.__tauri_android_on_key_down__ = (_keyCode: number) => {};
/** Android host bridge only */
export function onKeyDown(callback: KeyDownCodeCallback = (_keyCode: number) => {}) {
  window.__tauri_android_on_key_down__ = callback;
}
