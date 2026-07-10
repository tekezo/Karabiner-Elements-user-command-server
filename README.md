# Karabiner-Elements-user-command-server

This is a macOS menu bar app intended to be used with Karabiner-Elements `send_user_command`.
It supports the following commands:

- `set_window_frames`: Move and resize windows for the specified apps
- `center_focused_window`: Move the focused window to the center of its screen without resizing it
- `show_window_frames`: Collect current window information and show a payload example for `set_window_frames`

## Supported Commands

### `set_window_frames`

Applies position and size to windows of the specified app (`bundle_identifier`).
`x` can be either a number, `"left"`, `"center"`, or `"right"`.
`y` can be either a number, `"top"`, `"center"`, or `"bottom"`.
`"center"` uses the full screen frame, while edge values use the visible screen frame
that excludes the menu bar and Dock.

```json
{
  "command": "set_window_frames",
  "frames": [
    {
      "bundle_identifier": "com.apple.Terminal",
      "x": 100,
      "y": 80,
      "width": 1200,
      "height": 800
    },
    {
      "bundle_identifier": "com.apple.Safari",
      "x": "right",
      "y": "center",
      "width": 1400,
      "height": 900
    }
  ]
}
```

### `center_focused_window`

Moves the focused window to the center of the screen that contains it.
The window size is not changed.

```json
{
  "command": "center_focused_window"
}
```

### `show_window_frames`

Enumerates current window information and opens a window that shows a JSON example for `set_window_frames`.

```json
{
  "command": "show_window_frames"
}
```
