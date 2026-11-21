# Drawui Exporter (Roblox Studio plugin)

<img src="assets/icon-128.png" width="64" align="right">

Design your UI in Roblox Studio as usual, then export it as a Drawui script you can run in an executor.

## Install

```powershell
cd studio-plugin
.\build.ps1 -Install
```

Then restart Roblox Studio. A **Drawui** toolbar appears in the Plugins tab with two buttons:

- **Exporter** opens the panel with options.
- **Export** exports the current selection right away.

## Use

1. Select a `ScreenGui` or any GUI objects in the Explorer. With nothing selected, every ScreenGui in `StarterGui` is exported.
2. Click **Export**.
3. The script is saved to `ServerStorage.DrawuiExports` and opened in the script editor. Copy it into your executor.

Panel options:

| Option | Effect |
|---|---|
| Load Drawui from | `GitHub (latest)`, `GitHub (v1.0.0)` (pinned) or `readfile` (local `Drawui.luau`) |
| Add Activated stubs to buttons | adds `Activated = function() print(...) end` to every button |

## What gets exported

- `ScreenGui`, `Frame`, `CanvasGroup`, `TextLabel`, `TextButton`, `TextBox`, `ImageLabel`, `ImageButton`, `ScrollingFrame`
- Every property that differs from Drawui's default (`Position`, `Size`, `Rotation`, colours, text, alignment, `LayoutOrder`, `ZIndex`, ...).
  Values with no visible effect are left out, such as `BorderColor3` when `BorderSizePixel` is 0.
- Modifiers as builder sugar: `UICorner` → `Corner`, `UIStroke` → `Stroke`, `UIGradient` → `Gradient`, `UIPadding` → `Padding`,
  `UIListLayout` → `List`, `UIGridLayout` → `Grid`, `UIScale` → `Scale`, `UIAspectRatioConstraint` → `AspectRatio`,
  `UISizeConstraint` → `SizeLimit`, `UITextSizeConstraint` → `TextSizeLimit`, `UIShadow` → `Shadow` (all properties, including `Inset` and `Mode = "Text"`)
- Fonts: `Code` / `RobotoMono` become `UI.Fonts.Monospace`, `Arial` / `SourceSans` become `UI.Fonts.System`, and anything else uses the default UI font.

Anything Drawui can't reproduce is listed in a comment at the top of the script:

- unsupported classes (`ViewportFrame`, `VideoFrame`, `UIPageLayout`, ...), which are skipped
- unsupported properties (`RichText`, `TextTruncate`, `ScaleType`, `ImageRectSize`, ...)
- a second modifier of the same class on one object
- rotated objects that contain text or images (Drawui keeps those upright)
- `rbxassetid://` images, which most executors can't load through `Drawing` Image

Scripts and folders inside the UI are ignored.

## Development

- `src/Exporter.luau`: GUI → Drawui source. It is pure, so you can test it from the command bar.
- `src/Plugin.server.luau`: toolbar, panel and export action.
- `build.ps1`: bundles both into `build/DrawuiExporter.rbxmx`. `-Install` copies it to `%LOCALAPPDATA%\Roblox\Plugins`.
- `tools/make-icons.ps1 -Source logo.webp`: regenerates `assets/` from the logo. The toolbar icon is uploaded to
  Roblox, and its asset id is stored in `assets/icon-asset.txt`.
