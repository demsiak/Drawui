local UI = loadstring(readfile("Drawui.luau"))()
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.DrawuiDemo and env.DrawuiDemo.Cleanup then env.DrawuiDemo.Cleanup() end
local uis = game:GetService("UserInputService")
local New, Children = UI.New, UI.Children
local external = {}
local colors = {
    bg = Color3.fromRGB(17, 20, 29), panel = Color3.fromRGB(24, 28, 39),
    card = Color3.fromRGB(31, 36, 49), line = Color3.fromRGB(49, 57, 75),
    text = Color3.fromRGB(235, 240, 252), muted = Color3.fromRGB(141, 153, 178),
    accent = Color3.fromRGB(104, 141, 255), accent2 = Color3.fromRGB(150, 110, 255),
    green = Color3.fromRGB(91, 214, 164),
}
local accentGradient = { Color = { colors.accent, colors.accent2 }, Rotation = 0, ApplyToText = false }

local function label(parent, text, pos, size, textSize, color, props)
    local p = { Parent = parent, Text = text, Position = pos, Size = size, TextSize = textSize or 15,
        TextColor3 = color or colors.text, TextXAlignment = "Left", TextYAlignment = "Center" }
    for k, v in pairs(props or {}) do p[k] = v end
    return New "TextLabel" (p)
end
local function button(parent, text, pos, size, accent)
    return New "TextButton" { Parent = parent, Text = text, Position = pos, Size = size,
        BackgroundColor3 = accent and Color3.new(1, 1, 1) or colors.card, TextColor3 = colors.text, TextSize = 15,
        Corner = 7, Gradient = accent and accentGradient or nil }
end
local function setAccent(b, on)
    local g = b:FindFirstChildOfClass("UIGradient")
    if on and not g then New "UIGradient" (table.clone(accentGradient)).Parent = b
    elseif not on and g then g:Destroy() end
    b.BackgroundColor3 = on and Color3.new(1, 1, 1) or colors.card
end

local root = New "ScreenGui" { Name = "DrawuiDemo", DisplayOrder = 100 }
local window = New "Frame" { Parent = root, Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(750, 510), BackgroundColor3 = colors.bg,
    Corner = 12, Stroke = { Color = colors.line }, Shadow = { Blur = 24, Transparency = 0.45, Offset = Vector2.new(0, 10) } }
local scale = New "UIScale" { Parent = window, Scale = 1 }
local function fit()
    local cam = workspace.CurrentCamera
    if cam then scale.Scale = math.min(1, math.max(0.1, math.min((cam.ViewportSize.X - 24) / 750, (cam.ViewportSize.Y - 24) / 510))) end
end
fit()
table.insert(external, game:GetService("RunService").RenderStepped:Connect(fit))

local header = New "Frame" { Parent = window, Name = "TitleBar", Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1 }
New "Frame" { Parent = header, Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(27, 27),
    BackgroundColor3 = Color3.new(1, 1, 1), Corner = 7, Gradient = { Color = { colors.accent, colors.accent2 }, Rotation = 45 },
    [Children] = { label(nil, "D", UDim2.fromOffset(7, 0), UDim2.fromOffset(20, 27), 18) } }
label(header, "Drawui", UDim2.fromOffset(56, 10), UDim2.fromOffset(240, 23), 19)
label(header, "ROBLOX-STYLE OBJECTS / DRAWING.NEW", UDim2.fromOffset(56, 31), UDim2.fromOffset(410, 15), 10, colors.muted)
local close = button(header, "X", UDim2.new(1, -46, 0, 15), UDim2.fromOffset(29, 29))
New "Frame" { Parent = window, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = colors.line }
UI.MakeDraggable(window, header)

local sidebar = New "Frame" { Parent = window, Position = UDim2.fromOffset(0, 59), Size = UDim2.new(0, 166, 1, -59), BackgroundTransparency = 1 }
label(sidebar, "PLAYGROUND", UDim2.fromOffset(20, 18), UDim2.fromOffset(140, 20), 11, colors.muted)
label(sidebar, "100% Drawing.new", UDim2.new(0, 20, 1, -66), UDim2.fromOffset(140, 20), 12, colors.green)
label(sidebar, "RightShift: show / hide", UDim2.new(0, 20, 1, -44), UDim2.fromOffset(140, 20), 10, colors.muted)
New "Frame" { Parent = window, Position = UDim2.fromOffset(166, 59), Size = UDim2.new(0, 1, 1, -59), BackgroundColor3 = colors.line }
local content = New "Frame" { Parent = window, Position = UDim2.fromOffset(190, 80), Size = UDim2.new(1, -214, 1, -102), BackgroundTransparency = 1 }

local pages, tabs = {}, {}
for i, name in ipairs({ "Overview", "Controls", "Layout", "Styles" }) do
    pages[name] = New "Frame" { Parent = content, Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = i == 1 }
    tabs[name] = button(sidebar, name, UDim2.fromOffset(13, 53 + (i - 1) * 45), UDim2.fromOffset(140, 35), i == 1)
    tabs[name].MouseButton1Click:Connect(function()
        for key, page in pairs(pages) do page.Visible = key == name; setAccent(tabs[key], key == name) end
    end)
end

-- Overview ----------------------------------------------------------------------------------
local home = pages.Overview
label(home, "Build it like Roblox UI.", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 31), 25)
label(home, "Parent, UDim2, layouts and events. Drawn without GuiObjects.", UDim2.fromOffset(0, 36), UDim2.new(1, 0, 0, 22), 13, colors.muted)
local stats = New "Frame" { Parent = home, Position = UDim2.fromOffset(0, 79), Size = UDim2.new(1, 0, 0, 85), BackgroundTransparency = 1,
    Grid = { CellSize = UDim2.new(1 / 3, -7, 0, 85), CellPadding = UDim2.fromOffset(10, 0), FillDirectionMaxCells = 3 } }
for i, item in ipairs({ { "BACKEND", "Drawing.new" }, { "OBJECT MODEL", "Parent + props" }, { "DEPENDENCIES", "Zero remotes" } }) do
    New "Frame" { Parent = stats, LayoutOrder = i, BackgroundColor3 = colors.card, Corner = 8, Stroke = { Color = colors.line },
        [Children] = {
            label(nil, item[1], UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, 17), 10, colors.muted),
            label(nil, item[2], UDim2.fromOffset(12, 38), UDim2.new(1, -24, 0, 25), 15),
        } }
end
label(home, "Try a real event", UDim2.fromOffset(0, 191), UDim2.new(1, 0, 0, 24), 18)
local status = label(home, "Clicks: 0", UDim2.fromOffset(165, 234), UDim2.new(1, -165, 0, 38), 15, colors.green)
local clicks = 0
button(home, "Click me", UDim2.fromOffset(0, 234), UDim2.fromOffset(145, 38), true).MouseButton1Click:Connect(function()
    clicks += 1; status.Text = "Clicks: " .. clicks
end)
label(home, "TextBox", UDim2.fromOffset(0, 291), UDim2.fromOffset(100, 22), 13, colors.muted)
local input = New "TextBox" { Parent = home, Name = "NameInput", Position = UDim2.fromOffset(0, 320), Size = UDim2.new(1, 0, 0, 39),
    PlaceholderText = "Type something and press Enter...", BackgroundColor3 = colors.card, TextColor3 = colors.text,
    TextXAlignment = "Left", Corner = 8, Stroke = { Color = colors.line, ApplyStrokeMode = "Border" }, Padding = { Horizontal = 12 } }
input.FocusLost:Connect(function(enter) if enter then status.Text = input.Text == "" and "Empty input" or "Hello, " .. input.Text end end)
label(home, "Drag the title bar to move the window.", UDim2.fromOffset(0, 377), UDim2.new(1, 0, 0, 20), 12, colors.muted)

-- Controls ----------------------------------------------------------------------------------
local controls = pages.Controls
label(controls, "Small controls, real state.", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32), 24)
label(controls, "Built from Frame + TextButton, using the same public API.", UDim2.fromOffset(0, 38), UDim2.new(1, 0, 0, 22), 13, colors.muted)
local toggleRow = New "Frame" { Parent = controls, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = colors.card, Corner = 8 }
label(toggleRow, "Demo toggle", UDim2.fromOffset(16, 8), UDim2.fromOffset(260, 26), 16)
local toggleText = label(toggleRow, "Enabled", UDim2.fromOffset(16, 34), UDim2.fromOffset(260, 19), 12, colors.muted)
local enabled = true
local toggle = New "TextButton" { Parent = toggleRow, Text = "", Position = UDim2.new(1, -68, 0, 19), Size = UDim2.fromOffset(48, 28),
    BackgroundColor3 = colors.accent, Corner = UDim.new(0.5, 0) }
local knob = New "Frame" { Parent = toggle, Position = UDim2.fromOffset(24, 4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = colors.text,
    Corner = UDim.new(0.5, 0), Shadow = { Blur = 4, Offset = Vector2.new(0, 1), Transparency = 0.6 } }
toggle.MouseButton1Click:Connect(function()
    enabled = not enabled; toggleText.Text = enabled and "Enabled" or "Disabled"
    UI.Tween(toggle, TweenInfo.new(0.16), { BackgroundColor3 = enabled and colors.accent or colors.line })
    UI.Tween(knob, TweenInfo.new(0.16), { Position = UDim2.fromOffset(enabled and 24 or 4, 4) })
end)
label(controls, "Value", UDim2.fromOffset(0, 182), UDim2.fromOffset(230, 22), 16)
local valueLabel = label(controls, "50%", UDim2.new(1, -90, 0, 182), UDim2.fromOffset(90, 22), 15, colors.green, { TextXAlignment = "Right" })
local slider = New "Frame" { Parent = controls, Name = "Slider", Position = UDim2.fromOffset(0, 218), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Active = true }
local track = New "Frame" { Parent = slider, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = colors.line, Corner = 3 }
local fill = New "Frame" { Parent = track, Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), Corner = 3, Gradient = accentGradient }
local thumb = New "Frame" { Parent = slider, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
    BackgroundColor3 = colors.text, Corner = UDim.new(0.5, 0), Stroke = { Color = colors.accent, Thickness = 2 } }
local sliding = false
local function slide(x)
    local value = math.clamp((x - slider.AbsolutePosition.X) / math.max(1, slider.AbsoluteSize.X), 0, 1)
    fill.Size = UDim2.new(value, 0, 1, 0); thumb.Position = UDim2.fromScale(value, 0.5)
    valueLabel.Text = math.floor(value * 100 + 0.5) .. "%"
end
slider.InputBegan:Connect(function(event)
    if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then
        sliding = true; slide(event.Position.X)
    end
end)
table.insert(external, uis.InputChanged:Connect(function(event)
    if sliding and (event.UserInputType == Enum.UserInputType.MouseMovement or event.UserInputType == Enum.UserInputType.Touch) then slide(event.Position.X) end
end))
table.insert(external, uis.InputEnded:Connect(function(event)
    if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then sliding = false end
end))
local selectButton = button(controls, "Theme: Blue  >", UDim2.fromOffset(0, 275), UDim2.new(1, 0, 0, 39))
local options = New "Frame" { Parent = controls, Position = UDim2.fromOffset(0, 322), Size = UDim2.new(1, 0, 0, 76), BackgroundTransparency = 1, Visible = false, ZIndex = 5,
    Grid = { CellSize = UDim2.new(1 / 3, -7, 0, 36), CellPadding = UDim2.fromOffset(10, 0), FillDirectionMaxCells = 3 } }
selectButton.MouseButton1Click:Connect(function() options.Visible = not options.Visible end)
for i, item in ipairs({ { "Blue", Color3.fromRGB(104, 141, 255) }, { "Mint", Color3.fromRGB(59, 172, 136) }, { "Rose", Color3.fromRGB(204, 103, 151) } }) do
    local b = button(options, item[1], UDim2.new(), UDim2.new())
    b.LayoutOrder = i; b.BackgroundColor3 = item[2]
    b.MouseButton1Click:Connect(function()
        selectButton.Text = "Theme: " .. item[1] .. "  >"; selectButton.BackgroundColor3 = item[2]; options.Visible = false
    end)
end

-- Layout ------------------------------------------------------------------------------------
local layoutPage = pages.Layout
label(layoutPage, "Layouts that do the work.", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32), 24)
label(layoutPage, "UIListLayout + UIPadding + AutomaticCanvasSize. Scroll below.", UDim2.fromOffset(0, 38), UDim2.new(1, 0, 0, 22), 13, colors.muted)
local scroll = New "ScrollingFrame" { Parent = layoutPage, Name = "List", Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 1, -80),
    BackgroundColor3 = colors.panel, Corner = 8, Padding = { Left = 12, Right = 18, Top = 12, Bottom = 12 }, List = 9 }
for i = 1, 12 do
    New "Frame" { Parent = scroll, Name = "Row" .. i, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 57), BackgroundColor3 = colors.card, Corner = 6,
        [Children] = {
            label(nil, string.format("%02d", i), UDim2.fromOffset(13, 0), UDim2.fromOffset(32, 57), 17, colors.accent),
            label(nil, "List item " .. i, UDim2.fromOffset(55, 8), UDim2.new(1, -70, 0, 23), 15),
            label(nil, "Position comes from UIListLayout", UDim2.fromOffset(55, 31), UDim2.new(1, -70, 0, 17), 11, colors.muted),
        } }
end

-- Styles ------------------------------------------------------------------------------------
local styles = pages.Styles
label(styles, "Modifiers, drawn exactly.", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32), 24)
label(styles, "UICorner, UIStroke, UIGradient and UIShadow, built from Quads.", UDim2.fromOffset(0, 38), UDim2.new(1, 0, 0, 22), 13, colors.muted)
local swatches = New "Frame" { Parent = styles, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 1, -80), BackgroundTransparency = 1,
    Grid = { CellSize = UDim2.new(1 / 3, -10, 0, 140), CellPadding = UDim2.fromOffset(15, 18), FillDirectionMaxCells = 3 } }
local function swatch(order, caption, props)
    props.Parent = swatches; props.LayoutOrder = order
    props.BackgroundColor3 = props.BackgroundColor3 or colors.card
    local s = New "Frame" (props)
    label(s, caption, UDim2.new(0, 10, 1, -26), UDim2.new(1, -20, 0, 18), 11, colors.text, { ZIndex = 2 })
    return s
end
swatch(1, "UICorner 24px", { Corner = 24 })
swatch(2, "UICorner 0.5 (pill)", { Corner = UDim.new(0.5, 0), BackgroundColor3 = colors.panel, Stroke = { Color = colors.accent, Thickness = 2 } })
swatch(3, "UIStroke Center 3px", { Corner = 10, BackgroundTransparency = 1, Stroke = { Color = colors.green, Thickness = 3, BorderStrokePosition = "Center" } })
swatch(4, "UIGradient 45 deg", { Corner = 12, BackgroundColor3 = Color3.new(1, 1, 1),
    Gradient = { Color = { colors.accent, colors.accent2, Color3.fromRGB(255, 120, 170) }, Rotation = 45 } })
swatch(5, "Gradient transparency", { Corner = 12, BackgroundColor3 = colors.accent,
    Gradient = { Transparency = NumberSequence.new(0, 1), Rotation = 90 } })
swatch(6, "UIShadow", { Corner = 14, Shadow = { Blur = 20, Offset = Vector2.new(0, 8), Transparency = 0.3 }, Stroke = { Color = colors.line } })

-- Lifecycle ---------------------------------------------------------------------------------
local cleaned = false
local function cleanup()
    if cleaned then return end
    cleaned = true
    for _, c in ipairs(external) do c:Disconnect() end
    UI.Destroy()
    if env.DrawuiDemo and env.DrawuiDemo.Root == root then env.DrawuiDemo = nil end
end
close.MouseButton1Click:Connect(cleanup)
root.Destroying:Connect(function()
    for _, c in ipairs(external) do c:Disconnect() end
    if env.DrawuiDemo and env.DrawuiDemo.Root == root then env.DrawuiDemo = nil end
end)
table.insert(external, uis.InputBegan:Connect(function(event, processed)
    if not processed and event.KeyCode == Enum.KeyCode.RightShift and not UI.GetFocusedTextBox() then root.Enabled = not root.Enabled; sliding = false end
end))
env.DrawuiDemo = { UI = UI, Root = root, Cleanup = cleanup, Pages = pages }
UI.Refresh()
print("[Drawui] Demo ready. RightShift: show/hide. Drag title bar. X: destroy.")
return env.DrawuiDemo
