-- Drawui Exporter: Roblox Studio plugin that exports the selected GUI as a Drawui script.
-- `Exporter`, `ImageEmbed` and `ICON` are provided by the bundle (see build.ps1).
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

local LOADERS = {
	{ id = "github", label = "GitHub (latest)" },
	{ id = "pinned", label = "GitHub (v1.0.0)" },
	{ id = "file", label = "readfile" },
}

local options = {
	loader = plugin:GetSetting("loader") or "github",
	buttonStubs = plugin:GetSetting("buttonStubs") == true,
	embedImages = plugin:GetSetting("embedImages") ~= false,
}
local function save(key, value)
	options[key] = value
	plugin:SetSetting(key, value)
end

-- Selection -> exportable roots. Selecting a descendant of another selected object is ignored.
local function exportRoots()
	local roots = {}
	for _, inst in Selection:Get() do
		if Exporter.CanExport(inst) then table.insert(roots, inst) end
	end
	local out = {}
	for _, inst in roots do
		local nested = false
		for _, other in roots do
			if other ~= inst and inst:IsDescendantOf(other) then nested = true; break end
		end
		if not nested then table.insert(out, inst) end
	end
	if #out == 0 then
		-- Nothing usable selected: fall back to every ScreenGui in StarterGui.
		for _, child in StarterGui:GetChildren() do
			if child:IsA("ScreenGui") then table.insert(out, child) end
		end
	end
	return out
end

local function export()
	local roots = exportRoots()
	if #roots == 0 then
		return false, "Select a ScreenGui or GUI object (or put a ScreenGui in StarterGui)."
	end
	local source, warnings = Exporter.Export(roots, { loader = options.loader, buttonStubs = options.buttonStubs,
		encodeImage = options.embedImages and ImageEmbed.Encode or nil })

	local recording = ChangeHistoryService:TryBeginRecording("Drawui export")
	local folder = ServerStorage:FindFirstChild("DrawuiExports")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DrawuiExports"
		folder.Parent = ServerStorage
	end
	local script = Instance.new("Script")
	script.Name = (#roots == 1 and roots[1].Name or "Gui") .. ".drawui"
	script.Enabled = false
	script.Source = source
	script.Parent = folder
	if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end

	Selection:Set({ script })
	plugin:OpenScript(script)
	local message = "Exported " .. #roots .. " object" .. (#roots == 1 and "" or "s") .. " to ServerStorage.DrawuiExports." .. script.Name
	if #warnings > 0 then message ..= "\n" .. #warnings .. " item(s) not exported; see the comments at the top." end
	return true, message
end

-- Widget ---------------------------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("Drawui")
local panelButton = toolbar:CreateButton("DrawuiPanel", "Open the Drawui exporter", ICON, "Exporter")
local quickButton = toolbar:CreateButton("DrawuiQuickExport", "Export the selected GUI as a Drawui script", ICON, "Export")
panelButton.ClickableWhenViewportHidden = true
quickButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 300, 360, 260, 300)
local ok, widget = pcall(function() return plugin:CreateDockWidgetPluginGuiAsync("DrawuiExporter", widgetInfo) end)
if not ok then widget = plugin:CreateDockWidgetPluginGui("DrawuiExporter", widgetInfo) end
widget.Title = "Drawui Exporter"
widget.Name = "DrawuiExporter"

local theme = settings().Studio.Theme
local function c(style, modifier)
	return theme:GetColor(style, modifier or Enum.StudioStyleGuideModifier.Default)
end
local themed = {}
local function track(inst, prop, style, modifier)
	table.insert(themed, { inst, prop, style, modifier })
	inst[prop] = c(style, modifier)
end
local function applyTheme()
	theme = settings().Studio.Theme
	for _, t in themed do t[1][t[2]] = c(t[3], t[4]) end
end
settings().Studio.ThemeChanged:Connect(applyTheme)

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in props or {} do inst[k] = v end
	for _, child in children or {} do child.Parent = inst end
	return inst
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end

local root = new("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = widget,
}, {
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
track(root, "BackgroundColor3", Enum.StudioStyleGuideColor.MainBackground)

local header = new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = root })
new("ImageLabel", { Image = ICON, Size = UDim2.fromOffset(48, 48), BackgroundTransparency = 1, Parent = header }, { corner(10) })
local title = new("TextLabel", { Text = "Drawui Exporter", Font = Enum.Font.GothamBold, TextSize = 16, Position = UDim2.fromOffset(58, 4),
	Size = UDim2.new(1, -58, 0, 20), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local subtitle = new("TextLabel", { Text = "Roblox GUI → Drawui script", Font = Enum.Font.Gotham, TextSize = 12, Position = UDim2.fromOffset(58, 26),
	Size = UDim2.new(1, -58, 0, 16), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
track(title, "TextColor3", Enum.StudioStyleGuideColor.MainText)
track(subtitle, "TextColor3", Enum.StudioStyleGuideColor.DimmedText)

local function label(order, text)
	local l = new("TextLabel", { LayoutOrder = order, Text = text, Font = Enum.Font.GothamMedium, TextSize = 12, Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Parent = root })
	track(l, "TextColor3", Enum.StudioStyleGuideColor.DimmedText)
	return l
end

label(2, "LOAD DRAWUI FROM")
local loaderRow = new("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = root }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
})
local loaderButtons = {}
local function refreshLoaders()
	for id, b in loaderButtons do
		local active = options.loader == id
		b.BackgroundColor3 = active and c(Enum.StudioStyleGuideColor.DialogMainButton) or c(Enum.StudioStyleGuideColor.Button)
		b.TextColor3 = active and c(Enum.StudioStyleGuideColor.DialogMainButtonText) or c(Enum.StudioStyleGuideColor.ButtonText)
	end
end
for _, loader in LOADERS do
	local b = new("TextButton", { Text = loader.label, Font = Enum.Font.Gotham, TextSize = 11, AutoButtonColor = true,
		Size = UDim2.new(1 / #LOADERS, -4, 1, 0), Parent = loaderRow }, { corner(5) })
	loaderButtons[loader.id] = b
	b.Activated:Connect(function() save("loader", loader.id); refreshLoaders() end)
end
settings().Studio.ThemeChanged:Connect(refreshLoaders)
refreshLoaders()

label(4, "OPTIONS")
local function toggle(order, text, key)
	local row = new("TextButton", { LayoutOrder = order, Text = "", Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
		AutoButtonColor = false, Parent = root })
	local box = new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 3), Parent = row }, { corner(4) })
	local check = new("TextLabel", { Text = "✓", Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), Parent = box })
	local text = new("TextLabel", { Text = text, Font = Enum.Font.Gotham, TextSize = 12, Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -26, 1, 0), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	track(text, "TextColor3", Enum.StudioStyleGuideColor.MainText)
	local function refresh()
		box.BackgroundColor3 = options[key] and c(Enum.StudioStyleGuideColor.DialogMainButton) or c(Enum.StudioStyleGuideColor.InputFieldBackground)
		check.Visible = options[key]
	end
	row.Activated:Connect(function() save(key, not options[key]); refresh() end)
	settings().Studio.ThemeChanged:Connect(refresh)
	refresh()
end
toggle(5, "Add Activated stubs to buttons", "buttonStubs")
toggle(5, "Embed images in the script (recommended)", "embedImages")

local exportButton = new("TextButton", { LayoutOrder = 6, Text = "Export selection", Font = Enum.Font.GothamBold, TextSize = 14,
	Size = UDim2.new(1, 0, 0, 36), Parent = root }, { corner(6) })
track(exportButton, "BackgroundColor3", Enum.StudioStyleGuideColor.DialogMainButton)
track(exportButton, "TextColor3", Enum.StudioStyleGuideColor.DialogMainButtonText)

local status = new("TextLabel", { LayoutOrder = 7, Text = "", Font = Enum.Font.Gotham, TextSize = 12, Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
	Parent = root })
track(status, "TextColor3", Enum.StudioStyleGuideColor.DimmedText)

local help = new("TextLabel", { LayoutOrder = 8, Font = Enum.Font.Gotham, TextSize = 11, Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Select a ScreenGui or any GUI objects in the Explorer (nothing selected = every ScreenGui in StarterGui). "
		.. "The script is saved to ServerStorage.DrawuiExports and opened. Paste it into your executor.",
	Parent = root })
track(help, "TextColor3", Enum.StudioStyleGuideColor.DimmedText)

local function runExport()
	local ok, success, message = pcall(export)
	if not ok then
		status.Text = "Export failed: " .. tostring(success)
		warn("[Drawui] export failed: " .. tostring(success))
		return
	end
	status.Text = message
	if success then print("[Drawui] " .. message) else warn("[Drawui] " .. message) end
end

exportButton.Activated:Connect(runExport)
quickButton.Click:Connect(runExport)
panelButton.Click:Connect(function() widget.Enabled = not widget.Enabled end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function() panelButton:SetActive(widget.Enabled) end)
panelButton:SetActive(widget.Enabled)
