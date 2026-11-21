# Drawui

Roblox-style UI for [Potassium](https://docs.potassium.pro/api-reference/introduction), drawn entirely with
`Drawing.new`. It needs no ScreenGui instances, no hooks and no remotes.

You write UI the way you would in Roblox Studio: `Frame`, `TextButton`, `UDim2`, `UICorner`,
`UIListLayout`, events, tweens. Drawui handles layout, rendering, clipping and input.

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/demsiak/Drawui/main/Drawui.luau"))()
local New, Children = UI.New, UI.Children

New "Frame" {
    Parent = New "ScreenGui" {},
    Position = UDim2.fromOffset(100, 100),
    Size = UDim2.fromOffset(240, 80),
    Corner = 10,
    Stroke = Color3.fromRGB(60, 66, 85),
    Shadow = true,
    [Children] = {
        New "TextButton" {
            Text = "Click me",
            Position = UDim2.fromOffset(20, 20),
            Size = UDim2.fromOffset(200, 40),
            Corner = 8,
            Activated = function() print("clicked") end,
        },
    },
}
```

## Contents

- [Installation](#installation)
- [Two ways to create objects](#two-ways-to-create-objects)
- [Builder reference](#builder-reference)
- [Classes](#classes)
- [Modifiers](#modifiers)
- [Layout](#layout)
- [Events and input](#events-and-input)
- [Tweens and dragging](#tweens-and-dragging)
- [Object methods](#object-methods)
- [Library functions](#library-functions)
- [Re-running scripts and cleanup](#re-running-scripts-and-cleanup)
- [Custom classes and sugar](#custom-classes-and-sugar)
- [Limitations](#limitations)
- [VS Code extension](#vs-code-extension)
- [Development](#development)

## Installation

### From GitHub (recommended)

This needs no files: paste the line into Potassium and run it.

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/demsiak/Drawui/main/Drawui.luau"))()
```

`main` always points at the latest version. To pin a version that never changes, replace `main` with
a commit hash taken from the repository history:

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/demsiak/Drawui/<commit>/Drawui.luau"))()
```

### From a local file

This works offline. Copy `Drawui.luau` into Potassium's `workspace` folder, then:

```lua
local UI = loadstring(readfile("Drawui.luau"))()
```

### Examples

- [`examples/example.luau`](examples/example.luau) is a small window with a button, a text box and a counter.
- [`examples/demo.luau`](examples/demo.luau) is the full showcase with tabs, controls, layouts and every modifier.

Both load the library from GitHub, so you can paste and run them as they are.

## Two ways to create objects

**Builder** (declarative, recommended):

```lua
local New, Children = UI.New, UI.Children

local label = New "TextLabel" {
    Parent = frame,
    Text = "Hello",
    Size = UDim2.new(1, 0, 0, 24),
    TextXAlignment = "Left",
}
```

**Classic** (like `Instance.new`):

```lua
local label = UI.new("TextLabel")
label.Text = "Hello"
label.Size = UDim2.new(1, 0, 0, 24)
label.Parent = frame

-- or in one call: UI.new(class, props, children)
local label = UI.new("TextLabel", { Text = "Hello", Parent = frame })
```

Both return the same kind of object, so you can read and write properties, connect events and call methods
like on a Roblox instance. Enum properties accept strings (`"Left"`) or Roblox enums (`Enum.TextXAlignment.Left`).

## Builder reference

| Key | Meaning |
|---|---|
| `Prop = value` | sets a property (`Size`, `Text`, `BackgroundColor3`, ...) |
| `EventName = function` | connects an event (`Activated`, `FocusLost`, `MouseEnter`, ...) |
| `Parent = obj` | parent; applied last, after children and modifiers |
| `[UI.Children] = { ... }` | child objects; a string key (`Title = New ...`) also sets `Name` |
| `[UI.Ref] = function(obj)` | receives the created object (or pass a table: `ref.value` is set) |
| `[UI.OnEvent "Name"] = fn` | explicit event connection |
| `[UI.OnChange "Prop"] = fn` | called with the new value when a property changes |
| sugar keys | `Corner`, `Stroke`, `Gradient`, ... create modifiers; see below |

```lua
local status
local card = New "Frame" {
    Size = UDim2.fromOffset(260, 120),
    Corner = 10, Padding = 12, List = 6,
    [Children] = {
        Title = New "TextLabel" { Text = "Card", Size = UDim2.new(1, 0, 0, 20) },
        New "TextLabel" {
            Text = "Ready",
            Size = UDim2.new(1, 0, 0, 20),
            [UI.Ref] = function(obj) status = obj end,
        },
    },
    [UI.OnChange "AbsoluteSize"] = function(size) print("resized", size) end,
}
print(card.Title.Text) --> "Card" (children can be found by Name)
```

`UI.Hydrate(obj) { ... }` applies builder keys to an object that already exists.

### Sugar keys

| Key | Creates | Accepted values |
|---|---|---|
| `Corner` | UICorner | `8`, `UDim.new(0.5, 0)`, `{ CornerRadius = ... }` |
| `Stroke` | UIStroke | `Color3`, thickness number, `true`, or a props table |
| `Gradient` | UIGradient | `{ c1, c2, ... }`, `ColorSequence`, or `{ Color = ..., Rotation = ..., Transparency = ... }` |
| `Shadow` | UIShadow | `true` or `{ Blur = 20, Offset = Vector2.new(0, 8), Transparency = 0.4 }` |
| `Padding` | UIPadding | number / `UDim` for all sides, or `{ Left, Right, Top, Bottom, Horizontal, Vertical }` |
| `List` | UIListLayout | padding number, `true`, or a props table |
| `Grid` | UIGridLayout | props table (`CellSize`, `CellPadding`, ...) |
| `Scale` | UIScale | number |
| `AspectRatio` | UIAspectRatioConstraint | number or props table |
| `SizeLimit` | UISizeConstraint | `{ MinSize = ..., MaxSize = ... }` |
| `TextSizeLimit` | UITextSizeConstraint | `{ MinTextSize = ..., MaxTextSize = ... }` |

## Classes

All GUI objects share `Name`, `Visible`, `Position`, `Size`, `AnchorPoint`, `BackgroundColor3`,
`BackgroundTransparency`, `BorderColor3`, `BorderSizePixel`, `ZIndex`, `LayoutOrder`, `ClipsDescendants`,
`AutomaticSize`, `Active`, `Interactable`, plus the read-only `AbsolutePosition` and `AbsoluteSize`.

| Class | Extra properties |
|---|---|
| `ScreenGui` | `Enabled`, `DisplayOrder`, `IgnoreGuiInset`. The root: creating one starts the renderer |
| `Frame` | none |
| `CanvasGroup` | `GroupTransparency`, `GroupColor3` (fades / tints the whole subtree) |
| `TextLabel`, `TextButton`, `TextBox` | `Text`, `TextColor3`, `TextSize`, `Font`, `TextTransparency`, `TextXAlignment`, `TextYAlignment`, `TextWrapped`, `TextScaled`, `LineHeight`, `TextStrokeTransparency`, `TextStrokeColor3`, `TextBounds` (read-only) |
| `TextButton`, `ImageButton` | `AutoButtonColor` (hover / press shading) |
| `TextBox` | `PlaceholderText`, `PlaceholderColor3`, `ClearTextOnFocus`, `MultiLine`, `MaxLength`, `TextEditable`, `CursorPosition` |
| `ImageLabel`, `ImageButton` | `Image` (passed to Drawing `Image.Data`), `ImageColor3`, `ImageTransparency` |
| `ScrollingFrame` | `CanvasSize`, `CanvasPosition`, `AutomaticCanvasSize`, `ScrollingEnabled`, `ScrollingDirection`, `ScrollBarThickness`, `ScrollBarImageColor3`, `ScrollBarImageTransparency` |

`Font` takes `UI.Fonts.UI`, `UI.Fonts.System`, `UI.Fonts.Plex` or `UI.Fonts.Monospace` (Potassium's `Drawing.Fonts`).

## Modifiers

Modifiers are children that change their parent, as in Roblox.

| Class | Properties |
|---|---|
| `UICorner` | `CornerRadius` (UDim or number). Rounds the background, border, strokes, gradient, image and hit area. `UDim.new(0.5, 0)` gives a pill or circle |
| `UIStroke` | `Color`, `Thickness`, `Transparency`, `Enabled`, `ApplyStrokeMode` (`Contextual` outlines the text of text objects, `Border` always outlines the box), `BorderStrokePosition` (`Outer` / `Center` / `Inner`), `LineJoinMode` (`Round` / `Miter` / `Bevel`) |
| `UIGradient` | `Color` (ColorSequence, Color3 or a list of colours), `Transparency` (NumberSequence, number or a list), `Rotation` (any angle), `Offset`, `Enabled`, `ApplyToText`* |
| `UIShadow`* | `Color`, `Transparency`, `Offset`, `Blur`, `Spread`, `Enabled`: a soft drop shadow |
| `UIPadding` | `PaddingLeft`, `PaddingRight`, `PaddingTop`, `PaddingBottom` (UDim or number) |
| `UIListLayout` | `FillDirection`, `Padding`, `SortOrder`, `HorizontalAlignment`, `VerticalAlignment`, `Wraps`, `AbsoluteContentSize` |
| `UIGridLayout` | `CellSize`, `CellPadding`, `FillDirection`, `FillDirectionMaxCells`, `SortOrder`, alignments |
| `UIScale` | `Scale` (scales the object and its descendants) |
| `UIAspectRatioConstraint` | `AspectRatio`, `DominantAxis` |
| `UISizeConstraint` | `MinSize`, `MaxSize` |
| `UITextSizeConstraint` | `MinTextSize`, `MaxTextSize` (limits `TextScaled`) |

\* Drawui extensions that don't exist in Roblox. `UIGradient.ApplyToText = false` keeps text and image colours
untinted. The default is `true`, which matches Roblox.

```lua
New "TextButton" {
    Text = "Play",
    Size = UDim2.fromOffset(160, 40),
    BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient multiplies this colour
    Corner = 8,
    Gradient = { Color = { Color3.fromRGB(100, 140, 255), Color3.fromRGB(150, 110, 255) }, ApplyToText = false },
    Stroke = { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.8, ApplyStrokeMode = "Border" },
}
```

## Layout

- `Position` and `Size` are `UDim2` values relative to the parent's content area (after `UIPadding`).
  `AnchorPoint = Vector2.new(0.5, 0.5)` with `Position = UDim2.fromScale(0.5, 0.5)` centres an object.
- A `UIListLayout` or `UIGridLayout` (or `List =` / `Grid =`) positions children automatically. Order them with `LayoutOrder`.
- `AutomaticSize = "Y"` (or `"X"`, `"XY"`) grows an object to fit its children or text.
- A `ScrollingFrame` with `AutomaticCanvasSize = "Y"` (the default) scrolls whatever its layout produces.
- Set `ClipsDescendants = true` to clip children to the parent's box.

```lua
New "ScrollingFrame" {
    Size = UDim2.new(1, 0, 0, 200),
    Corner = 8, Padding = 8, List = 6,
    [Children] = (function()
        local rows = {}
        for i = 1, 20 do
            rows[i] = New "TextLabel" { Text = "Row " .. i, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i }
        end
        return rows
    end)(),
}
```

## Events and input

| Event | Arguments |
|---|---|
| `Activated` | `(input, clickCount)`: buttons |
| `MouseButton1Click`, `MouseButton2Click` | `()` |
| `MouseButton1Down`, `MouseButton1Up`, `MouseEnter`, `MouseLeave`, `MouseMoved` | `(x, y)` |
| `InputBegan`, `InputChanged`, `InputEnded` | `(input, processed)`: bubble up to parents |
| `Focused`, `FocusLost` | `()`, `(enterPressed, input)`: TextBox |
| `Changed` | `(propertyName)` |
| `ChildAdded`, `ChildRemoved`, `AncestryChanged`, `AttributeChanged`, `Destroying` | as in Roblox |

Objects receive mouse input when they are buttons, TextBoxes, ScrollingFrames, or have `Active = true`.
`Interactable = false` disables input. Hit testing respects `UICorner`.

The TextBox supports typing, Backspace / Delete, arrow keys, Home / End, Enter (`FocusLost(true)`),
Escape, key repeat, UTF-8 text and Ctrl+V (when the executor provides `getclipboard`).

## Tweens and dragging

```lua
UI.Tween(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
    BackgroundColor3 = Color3.fromRGB(104, 141, 255),
    Position = UDim2.fromOffset(40, 40),
})
frame:Tween(TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }) -- same thing

UI.MakeDraggable(window, titleBar) -- drag `window` by `titleBar` (defaults to the window itself)
```

Tweens work on `number`, `Color3`, `Vector2`, `UDim` and `UDim2` properties and return an object with
`Completed`, `PlaybackState` and `Cancel()`. A new tween on the same property cancels the old one.

## Object methods

`Destroy`, `Clone`, `ClearAllChildren`, `GetChildren`, `GetDescendants`, `FindFirstChild(name, recursive)`,
`FindFirstChildOfClass`, `FindFirstChildWhichIsA`, `FindFirstAncestor`, `FindFirstAncestorOfClass`, `IsA`,
`IsDescendantOf`, `GetPropertyChangedSignal`, `SetAttribute`, `GetAttribute`, `GetAttributes`, `Tween`.
TextBox only: `CaptureFocus`, `ReleaseFocus`, `IsFocused`.

`IsA` follows the class hierarchy: `TextButton:IsA("GuiButton")` and `Frame:IsA("GuiObject")` are true.

## Library functions

| Function | Description |
|---|---|
| `UI.New(class)(props)` | builder constructor |
| `UI.new(class, props, children)` / `UI.Create` | classic constructor |
| `UI.Hydrate(obj)(props)` | apply builder keys to an existing object |
| `UI.Tween(obj, info, goal)` | tween properties |
| `UI.MakeDraggable(target, handle)` | drag support; returns the connection |
| `UI.MeasureText(text, size, font)` | text bounds as a `Vector2` |
| `UI.GetFocusedTextBox()` | focused TextBox or `nil` |
| `UI.GetGuiObjectsAtPosition(x, y)` | interactive objects under a point, topmost first |
| `UI.Refresh()` | force an immediate layout and redraw |
| `UI.Destroy()` | destroy every object, remove all drawings, disconnect everything |
| `UI.GetStats()` | `{ Objects, Drawings, Roots, Connections, Tweens }` |
| `UI.Signal()` | a signal with `Connect`, `Once`, `Wait`, `Fire` |
| `UI.RegisterClass`, `UI.RegisterSugar`, `UI.GetClass`, `UI.GetClasses` | extending the library |
| `UI.Fonts`, `UI.Version` | constants |

## Re-running scripts and cleanup

Destroying the last `ScreenGui` (or calling `UI.Destroy()`) removes every drawing and disconnects the
renderer. Each `loadstring` creates a separate copy of the library, so when you re-run a script,
clean up the previous run first:

```lua
local env = getgenv()
if env.MyUI then env.MyUI.Destroy() end
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/demsiak/Drawui/main/Drawui.luau"))()
env.MyUI = UI
```

A hide / show key:

```lua
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift and not UI.GetFocusedTextBox() then
        gui.Enabled = not gui.Enabled
    end
end)
```

## Custom classes and sugar

Every class and modifier is a plain table of defaults and hooks, registered with `UI.RegisterClass`:

```lua
UI.RegisterClass("UIOutlineGlow", {
    Base = "UIComponent",
    Defaults = { Color = Color3.new(1, 1, 1), Enabled = true },
    Overlay = function(m, n, style, ctx)
        ctx.ring(n, style.pos, style.size, style.radius, 0, 6, m.Color, 0.25 * style.opacity, style.clip, true)
    end,
})

UI.RegisterSugar("Glow", function(node, color)
    UI.new("UIOutlineGlow", { Color = color, Parent = node })
end)

New "Frame" { Glow = Color3.fromRGB(100, 140, 255) }
```

The available hooks (`Style`, `Underlay`, `Overlay`, `Draw`, `Arrange`, `Padding`, `AdjustSize`, ...) are
documented at the top of [`src/Core/Registry.luau`](src/Core/Registry.luau).

## Limitations

- Drawing has no scissor or UV API. Rectangles, polygons, lines and text are clipped in software
  (text per character), but a partially clipped **image** is hidden.
- Translucent rounded shapes can show very faint lines inside their corners, because Potassium
  anti-aliases each primitive separately. Opaque shapes are drawn with overlapping pieces and have no seams.
- The TextBox cursor is drawn for single-line text only.
- Tweens don't support `RepeatCount` or `Reverses`.
- `UIShadow` is drawn as stacked layers, so very large blurs cost more drawings.

## VS Code extension

[`vscode/`](vscode) contains an extension for `.lua` / `.luau` files. It completes classes, properties,
sugar keys, events, enum values and `UI.` members, shows hover docs, and adds snippets (`drawui`, `dui-window`,
`dui-button`, `dui-textbox`, ...). Install it with:

```powershell
cd vscode
.\build-vsix.ps1
code --install-extension .\drawui-0.1.0.vsix
```

## Development

```
src/
  manifest.txt          module load order for the bundle
  Core/                 Util, Signal, Registry (class registry + hooks), Object (UI.new, Instance methods)
  Render/               Pool (drawing pool, clipping, polygons), Shapes (rounded rects, rings, gradients),
                        Text (measure, wrap, draw), Renderer (frame loop, draw pipeline)
  Layout/               sizing and placement pass
  Input/                hit testing, events, TextBox editing, drag, scroll
  Animation/            UI.Tween
  Classes/              one file per GuiObject class
  Modifiers/            UICorner, UIStroke, UIGradient, UIShadow, UIPadding, constraints, layouts
  Builder/              UI.New / Children / Ref / OnEvent / OnChange / Hydrate + sugar
examples/               example.luau, demo.luau
tests/                  headless Roblox / Drawing mock + spec
tools/Bundle.ps1        concatenates src/ into one chunk
vscode/                 VS Code extension
build.ps1               src/ -> Drawui.luau
test.ps1                runs the tests
```

`Drawui.luau` is generated. Edit the modules in `src/`, then run:

```powershell
.\build.ps1
```

The tests need the [Luau CLI](https://github.com/luau-lang/luau/releases):

```powershell
.\test.ps1 -LuauPath C:\path\to\luau.exe
```
