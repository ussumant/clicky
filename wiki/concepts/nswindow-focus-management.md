---
concept: NSWindow Focus Management
last_compiled: 2026-04-10
topics_connected: [app-core, overlay-ui, voice-pipeline]
status: active
---

# NSWindow Focus Management

## Pattern

Every UI surface in Clicky must be non-activating — it cannot steal focus from whatever app the user is working in. This constraint ripples through the entire architecture: the menu bar panel, the cursor overlay, and the response text bubble all use `NSPanel` configured as non-activating, non-main, and non-key. The same principle extends to the global push-to-talk shortcut, which uses a listen-only CGEvent tap specifically because AppKit's global monitor doesn't reliably detect modifier-only shortcuts when the app isn't focused.

This creates a consistent architectural tension: the app needs to render complex interactive UI (model picker, permissions flow, quit button) but must never become the active application. The solution is a two-tier approach — the menu bar panel IS activating (it's a deliberate user interaction), while everything else (overlay, response bubble) is strictly non-activating.

## Instances

- **app-core**: `MenuBarPanelManager` creates a borderless `NSPanel` with a global event monitor that auto-dismisses on outside clicks. The panel is the one exception that CAN become key window.
- **overlay-ui**: `OverlayWindow` is configured at `.screenSaver` window level, `canJoinAllSpaces`, `hidesOnDeactivate = false`. One overlay per monitor, all non-activating. The response bubble is a separate `NSPanel` from the cursor overlay.
- **voice-pipeline**: `GlobalPushToTalkShortcutMonitor` uses a listen-only `CGEvent` tap instead of `NSEvent.addGlobalMonitorForEvents` because modifier-based shortcuts (ctrl+option) aren't reliably detected when the app is backgrounded.

## What This Means

The non-activating constraint is the single most important architectural decision in Clicky. It means every new UI feature must be designed around the assumption that the app is never in focus. Standard SwiftUI patterns that rely on window activation, keyboard responders, or focus state don't work here — everything must be driven by global monitors, notifications, or the CGEvent tap.

## Sources

- [app-core](../topics/app-core.md)
- [overlay-ui](../topics/overlay-ui.md)
- [voice-pipeline](../topics/voice-pipeline.md)
