# Changelog

## 1.1.0

### Library
- `Rotation` on every GUI object (plus read-only `AbsoluteRotation`): rotates backgrounds, corners, strokes,
  gradients, shadows and hit areas of the whole subtree. Text and images stay upright (Drawing can't rotate them).
- `UIShadow` now has Roblox's API: `BlurRadius`, `Offset` / `Spread` (UDim2), `Inset` (inner shadow),
  `Mode = "Text"` (text drop shadow), `ShowBehindParent`. `Shadow = true` keeps the soft preset, and `Blur` is still
  accepted in the `Shadow` table. **Breaking:** `UI.new("UIShadow", { Blur = ... })` must use `BlurRadius`.

### VS Code extension
- Completion and hover for `Rotation`, `AbsoluteRotation` and the new `UIShadow` properties.

### Studio exporter
- Exports `Rotation` and `UIShadow` (all properties). Adds a note when rotated objects contain text or images.

## 1.0.0

The first release.

### Library
- Roblox-style object model: `ScreenGui`, `Frame`, `CanvasGroup`, `TextLabel`, `TextButton`, `TextBox`,
  `ImageLabel`, `ImageButton`, `ScrollingFrame`. Properties, `UDim2` layout, `AnchorPoint`, `ZIndex`,
  `ClipsDescendants`, `AutomaticSize`, events, attributes, `Clone`, `IsA` hierarchy.
- Modifiers: `UICorner`, `UIStroke` (Contextual / Border, Outer / Center / Inner), `UIGradient` (any rotation,
  colour and transparency sequences), `UIShadow`, `UIPadding`, `UIListLayout` (with `Wraps`), `UIGridLayout`,
  `UIScale`, `UIAspectRatioConstraint`, `UISizeConstraint`, `UITextSizeConstraint`.
- Declarative builder: `UI.New "Class" { ... }` with `[UI.Children]`, `[UI.Ref]`, `UI.OnEvent`, `UI.OnChange`,
  `UI.Hydrate` and sugar keys (`Corner`, `Stroke`, `Gradient`, `Shadow`, `Padding`, `List`, `Grid`, ...).
- Rendering with `Drawing.new` only: pooled drawings, writes only changed properties, software clipping,
  seamless opaque rounded shapes, pixel-snapped geometry.
- Input: hover / press / click, rounded hit areas, TextBox editing (UTF-8, key repeat, paste), dragging,
  scroll wheel and scrollbar.
- `UI.Tween`, `UI.MakeDraggable`, `UI.MeasureText`, `UI.GetGuiObjectsAtPosition`, `UI.Destroy`, `UI.GetStats`.
- Extensible: `UI.RegisterClass` (hooks for drawing, layout and sizing) and `UI.RegisterSugar`.

### Tooling
- Load from GitHub with `game:HttpGet`; no files needed.
- VS Code extension (`vscode/`) with completion, hover docs and snippets.
