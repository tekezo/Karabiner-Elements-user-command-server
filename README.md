# Karabiner-Elements-user-command-server

This is a macOS menu bar app intended to be used with Karabiner-Elements `send_user_command`.
It supports the following commands:

- `set_window_frames`: Move and resize windows for the specified apps
- `show_window_frames`: Collect current window information and show a payload example for `set_window_frames`

## Supported Commands

### `set_window_frames`

Applies position and size to windows of the specified app (`bundle_identifier`).
`x` can be either a number or `"center"`.

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
      "x": "center",
      "y": 60,
      "width": 1400,
      "height": 900
    }
  ]
}
```

### `show_window_frames`

Enumerates current window information and opens a window that shows a JSON example for `set_window_frames`.

```json
{
  "command": "show_window_frames"
}
```
