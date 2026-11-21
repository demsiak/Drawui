# Drawui

Roblox-style retained UI (ScreenGui, Frame, TextButton, UICorner, UIListLayout, ...) rendered only with
Potassium's `Drawing.new` (Square, Quad, Triangle, Line, Text, Image).

## Layout

```
src/
  manifest.txt          module load order for the bundle
  Core/                 Util, Signal, Registry (class registry + hooks), Object (UI.new, Instance methods)
  Render/               Pool (drawing pool, clipping, polygons), Shapes (rounded rects, rings, gradients),
                        Text (measure, wrap, draw), Renderer (frame loop, draw pipeline)
  Layout/               sizing + placement pass
  Input/                hit testing, events, TextBox editing, drag, scroll
  Animation/            UI.Tween
  Classes/              one file per GuiObject class
  Modifiers/            UICorner, UIStroke, UIGradient, UIShadow, UIPadding, constraints, layouts
  Builder/              declarative UI.New / Children / OnEvent / OnChange / Ref + sugar
examples/               example.luau (short), demo.luau (full showcase)
tests/                  headless mock + spec
tools/Bundle.ps1        concatenates src/ into a single chunk
build.ps1               src/ -> Drawui.luau
test.ps1                runs the tests
```

`Drawui.luau` is generated. Edit `src/`, then run `.\build.ps1`.

## Usage

Copy `Drawui.luau` into Potassium's `workspace` folder, then:

```lua
local UI = loadstring(readfile("Drawui.luau"))()
```

Run `examples/example.luau` or `examples/demo.luau` the same way.

## Modifiers

| Class | Properties |
|---|---|
| UICorner | CornerRadius (UDim or number). Rounds background, border, strokes, gradient, image and hit area |
| UIStroke | Color, Thickness, Transparency, Enabled, ApplyStrokeMode (Contextual / Border), BorderStrokePosition (Outer / Center / Inner), LineJoinMode |
| UIGradient | Color (ColorSequence, Color3 or a list), Transparency (NumberSequence, number or a list), Rotation (any angle), Offset, Enabled |
| UIShadow *(extension)* | Color, Transparency, Offset, Blur, Spread, Enabled |
| UIPadding | PaddingLeft/Right/Top/Bottom (UDim or number) |
| UIListLayout | FillDirection, Padding, SortOrder, alignments, **Wraps** |
| UIGridLayout | CellSize, CellPadding, FillDirectionMaxCells, ... |
| UIScale, UIAspectRatioConstraint, UISizeConstraint, UITextSizeConstraint | as on Roblox |

## Builder

```lua
local New, Children = UI.New, UI.Children
local card = New "Frame" {
    Parent = screen,
    Size = UDim2.fromOffset(260, 120),
    Corner = 10, Padding = 12, List = 6,
    Stroke = { Color = Color3.fromRGB(60, 66, 85) },
    Gradient = { Color = { Color3.fromRGB(40, 44, 60), Color3.fromRGB(26, 28, 38) }, Rotation = 90 },
    Shadow = { Blur = 20, Offset = Vector2.new(0, 8) },
    [Children] = {
        Title = New "TextLabel" { Text = "Hello", Size = UDim2.new(1, 0, 0, 20) },
        New "TextButton" { Text = "Go", Size = UDim2.new(1, 0, 0, 32), Corner = 6,
            Activated = function() print("go") end },
    },
    [UI.OnChange "AbsoluteSize"] = function(size) end,
}
```

Sugar keys: `Corner`, `Stroke`, `Gradient`, `Shadow`, `Padding`, `Scale`, `AspectRatio`, `SizeLimit`,
`TextSizeLimit`, `List`, `Grid`. Add your own with `UI.RegisterSugar(name, function(node, value) end)`.

## Custom classes

```lua
UI.RegisterClass("UIOutlineGlow", {
    Base = "UIComponent",
    Defaults = { Color = Color3.new(1, 1, 1), Enabled = true },
    Overlay = function(m, n, style, ctx)
        ctx.ring(n, style.pos, style.size, style.radius, 0, 6, m.Color, 0.25 * style.opacity, style.clip, true)
    end,
})
```

The hooks are listed at the top of `src/Core/Registry.luau`.

## Testing

```powershell
.\test.ps1 -LuauPath C:\path\to\luau.exe
```

