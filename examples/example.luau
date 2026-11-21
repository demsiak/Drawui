local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/demsiak/Drawui/main/Drawui.luau"))()
local New, Children = UI.New, UI.Children

local clicks = 0
local status, input

local gui = New "ScreenGui" {}

local window = New "Frame" {
    Parent = gui,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(320, 220),
    BackgroundColor3 = Color3.fromRGB(20, 22, 30),
    Corner = 12,
    Stroke = Color3.fromRGB(50, 55, 70),
    Shadow = true,
    Padding = 16,
    List = 10,
    [Children] = {
        New "TextLabel" {
            Text = "Hello",
            Size = UDim2.new(1, 0, 0, 24),
            TextSize = 20,
            TextXAlignment = "Left",
        },
        New "TextButton" {
            Text = "Click me",
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Color3.new(1, 1, 1),
            Corner = 8,
            Gradient = { Color = { Color3.fromRGB(100, 140, 255), Color3.fromRGB(150, 110, 255) }, ApplyToText = false },
            Activated = function()
                clicks += 1
                status.Text = "Clicks: " .. clicks
            end,
        },
        New "TextBox" {
            PlaceholderText = "Type and press Enter...",
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Color3.fromRGB(30, 33, 44),
            TextXAlignment = "Left",
            Corner = 8,
            Padding = { Horizontal = 10 },
            [UI.Ref] = function(box) input = box end,
            FocusLost = function(enter)
                if enter then status.Text = "Hello, " .. input.Text end
            end,
        },
        New "TextLabel" {
            Text = "Clicks: 0",
            Size = UDim2.new(1, 0, 0, 20),
            TextColor3 = Color3.fromRGB(90, 215, 165),
            TextXAlignment = "Left",
            [UI.Ref] = function(label) status = label end,
        },
    },
}

UI.MakeDraggable(window)
