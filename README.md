# PortionShare

Share just a **portion** of your Mac's screen in Zoom — or Google Meet, Slack,
Teams, Discord, anything that can share a single window.

Zoom's window picker can't crop a region of your screen, and sharing your whole
display means exposing notifications, Slack, and whatever else is open.
PortionShare fixes that: drag-select any region of your screen, and it opens a
window that mirrors that region live. Share *that* window in your meeting.
Everything outside the region stays private.

## Features

- **Drag to select** any region on any display
- **Live mirror window** to share at full resolution: one window pixel per
  captured pixel (Retina included), 30 fps, cursor included
- **Orange outline** on screen shows exactly what viewers can see
- **Self-exclusion** — the mirror window and outline are filtered out of the
  capture, so there's no hall-of-mirrors even if they overlap your selection
- **Re-select mid-call** with Cmd+R; the shared window stays the same, so your
  Zoom share never drops
- Native Swift + [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit),
  no dependencies, ~400 lines of code

## Install

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/davidgeorgehope/portionshare.git
cd portionshare
./build.sh
open dist/PortionShare.app
```

App icon lives in `Resources/AppIcon.icns` (Grok Imagine). Regenerate with
`./generate_icon.sh` then `./build.sh`.

On first launch, macOS will ask for **Screen Recording** permission. Grant it
in System Settings → Privacy & Security → Screen Recording, then reopen the
app.

`build.sh` signs with `SIGN_IDENTITY`, or else your keychain's first
code-signing identity, so the permission survives rebuilds. With no identity
it signs ad-hoc, and macOS asks again after every rebuild. If the permission
gets stuck, `tccutil reset All local.portionshare` clears it.

## Usage

1. Launch PortionShare. The screen dims — drag to select the region you want
   to share (Esc cancels).
2. A mirror window opens with a live view of that region, and an orange
   outline marks the captured area on screen. If you have another display,
   the mirror always opens there, off the screen you're presenting from. It
   doesn't need to be visible to you, so even a display you never look at works.
3. In Zoom: **Share Screen → select the "PortionShare" window → Share.**
4. Work normally inside the outlined region. Viewers only ever see that area.

| Shortcut | Action |
|---|---|
| Cmd+R | Select a new region (keeps the current share alive) |
| Esc | Cancel region selection |
| Cmd+Q / close window | Quit |

## How it works

Meeting apps can't be fed an arbitrary screen region, but they can all share a
single window. PortionShare uses ScreenCaptureKit to stream the selected
display rectangle (`SCStreamConfiguration.sourceRect`) into an
`AVSampleBufferDisplayLayer` hosted in a plain AppKit window — the window you
share. The capture filter excludes PortionShare's own windows, which is why
the mirror and the outline never appear in the stream.

Meeting apps and browsers share the window's pixels, so the mirror is sized to
exactly the capture's pixel count on whatever display it's on (half the points
on a Retina display, the same points on a 1x one) and isn't resizable. A
smaller window would silently downscale what viewers see. If it doesn't fit on
the other display, it hangs off the edge facing away from your region, which
window capture still includes (checked with Chrome's screen sharing). The
selection is also
snapped to the display's pixel grid, because ScreenCaptureKit resamples every
frame of a `sourceRect` that isn't pixel-aligned.

Source layout:

| File | Purpose |
|---|---|
| `SelectionController.swift` | Dimmed drag-to-select overlay across all displays |
| `CaptureController.swift` | ScreenCaptureKit stream of the selected rectangle |
| `MirrorWindow.swift` | The live mirror window you share |
| `BorderWindow.swift` | Click-through outline around the captured region |
| `AppDelegate.swift` | Wires selection → capture → mirror together |

## Development

```bash
./test.sh
```

`test.sh` wraps `swift test` and adds the Swift Testing search paths SwiftPM
misses when only the Command Line Tools are installed.

## FAQ

**Is anything uploaded anywhere?**
No. PortionShare never touches the network. The capture stays on your Mac;
your meeting app only sees a regular window.

**Why does it need Screen Recording permission?**
That's the macOS permission gating ScreenCaptureKit — it's required to read
any pixels from the screen, even a small region you selected yourself.

**Zoom has "Share a portion of screen" under Advanced — why this?**
Zoom's built-in option works, but it's buried, Zoom-only, and re-crops every
meeting. PortionShare gives you a persistent, resizable region with a visible
outline, works across every meeting app, and lets you switch regions with a
keystroke.

## License

[MIT](LICENSE)
