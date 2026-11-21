-- Exporter: turns Roblox GUI instances into a Drawui builder script.
-- Only values that differ from Drawui's defaults are written. Modifiers become sugar keys
-- (Corner, Stroke, Gradient, Padding, List, ...). Anything Drawui can't draw is listed as a
-- comment at the top of the script.
local Exporter = {}

Exporter.Loaders = {
	github = 'local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/demsiak/Drawui/main/Drawui.luau"))()',
	pinned = 'local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/demsiak/Drawui/v1.0.0/Drawui.luau"))()',
	file = 'local UI = loadstring(readfile("Drawui.luau"))()',
}

-- Formatting ----------------------------------------------------------------------------------

local function num(n)
	if n == math.huge then return "math.huge" end
	if n == -math.huge then return "-math.huge" end
	if math.abs(n - math.round(n)) < 1e-6 then return string.format("%d", math.round(n)) end
	local s = string.format("%.4f", n):gsub("0+$", ""):gsub("%.$", "")
	return s
end

local function str(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		if c == "\n" then return "\\n" end
		if c == "\t" then return "\\t" end
		if c == "\r" then return "\\r" end
		if c == '"' then return '\\"' end
		if c == "\\" then return "\\\\" end
		return string.format("\\%03d", string.byte(c))
	end) .. '"'
end

local function color(c)
	return string.format("Color3.fromRGB(%d, %d, %d)", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

local function udim(u)
	if u.Scale == 0 then return num(u.Offset) end
	return string.format("UDim.new(%s, %s)", num(u.Scale), num(u.Offset))
end

local function value(v)
	local kind = typeof(v)
	if kind == "string" then return str(v) end
	if kind == "number" then return num(v) end
	if kind == "boolean" then return tostring(v) end
	if kind == "Color3" then return color(v) end
	if kind == "EnumItem" then return str(v.Name) end
	if kind == "Vector2" then return string.format("Vector2.new(%s, %s)", num(v.X), num(v.Y)) end
	if kind == "UDim" then return string.format("UDim.new(%s, %s)", num(v.Scale), num(v.Offset)) end
	if kind == "UDim2" then
		if v.X.Scale == 0 and v.Y.Scale == 0 then return string.format("UDim2.fromOffset(%s, %s)", num(v.X.Offset), num(v.Y.Offset)) end
		if v.X.Offset == 0 and v.Y.Offset == 0 then return string.format("UDim2.fromScale(%s, %s)", num(v.X.Scale), num(v.Y.Scale)) end
		return string.format("UDim2.new(%s, %s, %s, %s)", num(v.X.Scale), num(v.X.Offset), num(v.Y.Scale), num(v.Y.Offset))
	end
	if kind == "ColorSequence" then
		local k = v.Keypoints
		if #k == 2 and k[1].Time == 0 and k[2].Time == 1 then
			return "{ " .. color(k[1].Value) .. ", " .. color(k[2].Value) .. " }"
		end
		local parts = {}
		for _, p in k do table.insert(parts, "{ " .. num(p.Time) .. ", " .. color(p.Value) .. " }") end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	if kind == "NumberSequence" then
		local parts = {}
		for _, p in v.Keypoints do table.insert(parts, "{ " .. num(p.Time) .. ", " .. num(p.Value) .. " }") end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return "nil --[[ " .. kind .. " ]]"
end
Exporter.Format = value

local function same(a, b)
	if typeof(a) == "number" and typeof(b) == "number" then return math.abs(a - b) < 1e-5 end
	if typeof(a) == "EnumItem" then return a.Name == b end
	if typeof(a) == "Color3" and typeof(b) == "Color3" then
		return math.round(a.R * 255) == math.round(b.R * 255) and math.round(a.G * 255) == math.round(b.G * 255)
			and math.round(a.B * 255) == math.round(b.B * 255)
	end
	return a == b
end

local function read(inst, prop)
	local ok, v = pcall(function() return inst[prop] end)
	if ok then return v end
	return nil
end

-- Drawui defaults -------------------------------------------------------------------------------
-- { property, Drawui default } in output order. Values equal to the default are skipped.

local rgb = Color3.fromRGB
local GUI = {
	{ "AnchorPoint", Vector2.zero }, { "Position", UDim2.new() }, { "Size", UDim2.fromOffset(100, 100) },
	{ "AutomaticSize", "None" }, { "BackgroundColor3", rgb(30, 33, 43) }, { "BackgroundTransparency", 0 },
	{ "BorderColor3", rgb(64, 69, 85) }, { "BorderSizePixel", 0 }, { "Visible", true }, { "ZIndex", 1 },
	{ "LayoutOrder", 0 }, { "ClipsDescendants", false }, { "Interactable", true }, { "Rotation", 0 },
}
local TEXT = {
	{ "TextColor3", rgb(255, 255, 255) }, { "TextSize", 16 }, { "TextTransparency", 0 },
	{ "TextXAlignment", "Center" }, { "TextYAlignment", "Center" }, { "TextWrapped", false }, { "TextScaled", false },
	{ "LineHeight", 1.15 }, { "TextStrokeTransparency", 1 }, { "TextStrokeColor3", rgb(0, 0, 0) },
}
local IMAGE = { { "Image", "" }, { "ImageColor3", rgb(255, 255, 255) }, { "ImageTransparency", 0 } }

local function list(...)
	local out = {}
	for _, group in { ... } do for _, entry in group do table.insert(out, entry) end end
	return out
end

local CLASSES = {
	ScreenGui = { { "DisplayOrder", 0 }, { "Enabled", true }, { "IgnoreGuiInset", true } },
	Frame = GUI,
	CanvasGroup = list(GUI, { { "GroupTransparency", 0 }, { "GroupColor3", rgb(255, 255, 255) } }),
	TextLabel = list({ { "Text", "TextLabel" } }, GUI, TEXT, { { "BackgroundTransparency", 1 } }),
	TextButton = list({ { "Text", "TextButton" } }, GUI, TEXT, { { "AutoButtonColor", true }, { "Active", true } }),
	TextBox = list({ { "Text", "" }, { "PlaceholderText", "" } }, GUI, TEXT, {
		{ "PlaceholderColor3", rgb(140, 146, 165) }, { "ClearTextOnFocus", false }, { "MultiLine", false },
		{ "TextEditable", true }, { "Active", true },
	}),
	ImageLabel = list(GUI, IMAGE),
	ImageButton = list(GUI, IMAGE, { { "AutoButtonColor", true }, { "Active", true } }),
	ScrollingFrame = list(GUI, {
		{ "CanvasSize", UDim2.new() }, { "AutomaticCanvasSize", "Y" }, { "ScrollingEnabled", true },
		{ "ScrollingDirection", "Y" }, { "ScrollBarThickness", 5 }, { "ScrollBarImageColor3", rgb(113, 125, 155) },
		{ "ScrollBarImageTransparency", 0.1 }, { "ClipsDescendants", true }, { "Active", true },
	}),
}
-- Later entries override earlier ones (e.g. TextLabel's transparent background).
for name, entries in CLASSES do
	local seen, out = {}, {}
	for i = #entries, 1, -1 do
		local e = entries[i]
		if not seen[e[1]] then seen[e[1]] = true; table.insert(out, 1, e) end
	end
	CLASSES[name] = out
end

-- Properties that have no visible effect in the given state are not written.
local HIDDEN = {
	BorderColor3 = function(i) return i.BorderSizePixel == 0 end,
	BackgroundColor3 = function(i) return i.BackgroundTransparency >= 1 end,
	TextStrokeColor3 = function(i) return i.TextStrokeTransparency >= 1 end,
	PlaceholderColor3 = function(i) return i.PlaceholderText == "" end,
	ScrollBarImageColor3 = function(i) return i.ScrollBarThickness == 0 end,
	ScrollBarImageTransparency = function(i) return i.ScrollBarThickness == 0 end,
	ImageColor3 = function(i) return i.Image == "" end,
	ImageTransparency = function(i) return i.Image == "" end,
}

local MODIFIERS = {
	UICorner = true, UIStroke = true, UIGradient = true, UIPadding = true, UIListLayout = true, UIGridLayout = true,
	UIScale = true, UIAspectRatioConstraint = true, UISizeConstraint = true, UITextSizeConstraint = true, UIShadow = true,
}
-- Children that are fine to drop silently (scripts, values, folders of tooling).
local IGNORED = { Script = true, LocalScript = true, ModuleScript = true, Folder = true, Configuration = true }

-- Properties Drawui doesn't support: reported when they differ from Roblox's default.
local UNSUPPORTED = {
	{ "RichText", false }, { "TextTruncate", "None" }, { "ScaleType", "Stretch" },
	{ "ImageRectSize", Vector2.zero }, { "ImageRectOffset", Vector2.zero }, { "SizeConstraint", "RelativeXY" },
	{ "BorderMode", "Outline" },
}

local function fontValue(inst)
	local font = read(inst, "Font")
	local name = font and font.Name or ""
	if name == "Unknown" then
		local face = read(inst, "FontFace")
		name = face and tostring(face.Family):match("([%w]+)%.json$") or ""
	end
	if name == "Code" or name == "RobotoMono" or name == "Ubuntu" or name == "Inconsolata" then return "UI.Fonts.Monospace" end
	if name == "Arial" or name == "ArialBold" or name == "Legacy" or name:find("^SourceSans") then return "UI.Fonts.System" end
	return nil
end

-- Writer ------------------------------------------------------------------------------------------

local Writer = {}
Writer.__index = Writer
local function newWriter(options)
	return setmetatable({ lines = {}, warnings = {}, options = options or {} }, Writer)
end
function Writer:line(depth, text) table.insert(self.lines, string.rep("\t", depth) .. text) end
function Writer:warn(inst, text) table.insert(self.warnings, inst:GetFullName() .. ": " .. text) end

local function propsTable(entries)
	return "{ " .. table.concat(entries, ", ") .. " }"
end

-- Modifier -> sugar entry ("Corner = 8") or nil when it must be written as a child.
local function sugar(m)
	local c = m.ClassName
	if c == "UICorner" then
		return "Corner = " .. udim(m.CornerRadius)
	elseif c == "UIStroke" then
		local entries = {}
		local function add(prop, default)
			local v = read(m, prop)
			if v ~= nil and not same(v, default) then table.insert(entries, prop .. " = " .. value(v)) end
		end
		add("Color", rgb(75, 82, 103)); add("Thickness", 1); add("Transparency", 0); add("Enabled", true)
		add("ApplyStrokeMode", "Contextual"); add("LineJoinMode", "Round"); add("BorderStrokePosition", "Outer")
		if #entries == 0 then return "Stroke = true" end
		if #entries == 1 and entries[1]:find("^Color = ") then return "Stroke = " .. entries[1]:sub(9) end
		return "Stroke = " .. propsTable(entries)
	elseif c == "UIGradient" then
		local entries = { "Color = " .. value(m.Color) }
		local t = m.Transparency.Keypoints
		local constantZero = true
		for _, p in t do if p.Value ~= 0 then constantZero = false end end
		if not constantZero then table.insert(entries, "Transparency = " .. value(m.Transparency)) end
		if m.Rotation ~= 0 then table.insert(entries, "Rotation = " .. num(m.Rotation)) end
		if m.Offset ~= Vector2.zero then table.insert(entries, "Offset = " .. value(m.Offset)) end
		if not m.Enabled then table.insert(entries, "Enabled = false") end
		return "Gradient = " .. propsTable(entries)
	elseif c == "UIPadding" then
		local l, r, t, b = m.PaddingLeft, m.PaddingRight, m.PaddingTop, m.PaddingBottom
		if l == r and r == t and t == b then return "Padding = " .. udim(l) end
		local entries = {}
		if l == r then table.insert(entries, "Horizontal = " .. udim(l))
		else table.insert(entries, "Left = " .. udim(l)); table.insert(entries, "Right = " .. udim(r)) end
		if t == b then table.insert(entries, "Vertical = " .. udim(t))
		else table.insert(entries, "Top = " .. udim(t)); table.insert(entries, "Bottom = " .. udim(b)) end
		return "Padding = " .. propsTable(entries)
	elseif c == "UIListLayout" or c == "UIGridLayout" then
		local entries = {}
		local function add(prop, default)
			local v = read(m, prop)
			if v ~= nil and not same(v, default) then table.insert(entries, prop .. " = " .. value(v)) end
		end
		if c == "UIListLayout" then
			if m.Padding ~= UDim.new() then table.insert(entries, "Padding = " .. udim(m.Padding)) end
			add("FillDirection", "Vertical"); add("Wraps", false)
		else
			add("CellSize", UDim2.fromOffset(100, 40)); add("CellPadding", UDim2.fromOffset(8, 8))
			add("FillDirection", "Horizontal"); add("FillDirectionMaxCells", 0)
		end
		add("SortOrder", "LayoutOrder"); add("HorizontalAlignment", "Left"); add("VerticalAlignment", "Top")
		local key = c == "UIListLayout" and "List" or "Grid"
		if #entries == 0 then return key .. " = true" end
		if c == "UIListLayout" and #entries == 1 and entries[1]:find("^Padding = ") then return "List = " .. entries[1]:sub(11) end
		return key .. " = " .. propsTable(entries)
	elseif c == "UIScale" then
		return "Scale = " .. num(m.Scale)
	elseif c == "UIAspectRatioConstraint" then
		if m.DominantAxis.Name == "Width" and m.AspectType.Name == "FitWithinMaxSize" then return "AspectRatio = " .. num(m.AspectRatio) end
		return "AspectRatio = " .. propsTable({ "AspectRatio = " .. num(m.AspectRatio), "DominantAxis = " .. value(m.DominantAxis),
			"AspectType = " .. value(m.AspectType) })
	elseif c == "UISizeConstraint" then
		return "SizeLimit = " .. propsTable({ "MinSize = " .. value(m.MinSize), "MaxSize = " .. value(m.MaxSize) })
	elseif c == "UITextSizeConstraint" then
		return "TextSizeLimit = " .. propsTable({ "MinTextSize = " .. num(m.MinTextSize), "MaxTextSize = " .. num(m.MaxTextSize) })
	elseif c == "UIShadow" then
		-- A table is passed through as-is (no preset), so only Roblox-default values are left out.
		local entries = {}
		local function add(prop, default, format)
			local v = read(m, prop)
			if v ~= nil and not same(v, default) then table.insert(entries, prop .. " = " .. (format or value)(v)) end
		end
		add("BlurRadius", UDim.new(), udim); add("Offset", UDim2.new()); add("Spread", UDim2.new())
		add("Color", rgb(0, 0, 0)); add("Transparency", 0); add("Inset", false); add("Mode", "Shape")
		add("ShowBehindParent", true); add("Enabled", true)
		return "Shadow = " .. propsTable(entries)
	end
end

function Writer:object(inst, depth, extra)
	local spec = CLASSES[inst.ClassName]
	local entries = {}
	if extra then for _, e in extra do table.insert(entries, e) end end
	if inst.Name ~= inst.ClassName then table.insert(entries, "Name = " .. str(inst.Name)) end
	for _, entry in spec do
		local prop, default = entry[1], entry[2]
		local v = read(inst, prop)
		if v ~= nil and not same(v, default) and not (HIDDEN[prop] and HIDDEN[prop](inst)) then
			table.insert(entries, prop .. " = " .. value(v))
		end
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		local font = fontValue(inst)
		if font then table.insert(entries, "Font = " .. font) end
	end
	for _, u in UNSUPPORTED do
		local v = read(inst, u[1])
		if v ~= nil and u[2] ~= nil and not same(v, u[2]) then self:warn(inst, u[1] .. " = " .. value(v) .. " is not supported") end
	end
	if read(inst, "Rotation") and inst.Rotation % 360 ~= 0 then
		local upright = {}
		for _, d in { inst, table.unpack(inst:GetDescendants()) } do
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") or d:IsA("ImageLabel") or d:IsA("ImageButton") then
				table.insert(upright, d.Name)
			end
		end
		if #upright > 0 then
			self:warn(inst, "rotated; Drawui keeps text and images upright (" .. table.concat(upright, ", ", 1, math.min(#upright, 4))
				.. (#upright > 4 and ", ..." or "") .. ")")
		end
	end
	if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and inst.Image ~= "" then
		self:warn(inst, "Image " .. inst.Image .. " is passed to Drawing Image.Data as-is; most executors need image data or a URL")
	end
	if self.options.buttonStubs and (inst:IsA("TextButton") or inst:IsA("ImageButton")) then
		table.insert(entries, "Activated = function()\n" .. string.rep("\t", depth + 2) .. "print(" .. str(inst.Name .. " clicked") .. ")\n" .. string.rep("\t", depth + 1) .. "end")
	end

	local children, usedSugar = {}, {}
	for _, child in inst:GetChildren() do
		if MODIFIERS[child.ClassName] and not usedSugar[child.ClassName] then
			usedSugar[child.ClassName] = true
			table.insert(entries, sugar(child))
		elseif MODIFIERS[child.ClassName] then
			self:warn(child, "only the first " .. child.ClassName .. " of an object is exported")
		elseif CLASSES[child.ClassName] and child.ClassName ~= "ScreenGui" then
			table.insert(children, child)
		elseif not IGNORED[child.ClassName] then
			self:warn(child, child.ClassName .. " is not supported by Drawui and was skipped")
		end
	end

	self:line(0, "")
	local header = 'New "' .. inst.ClassName .. '" {'
	if #entries == 0 and #children == 0 then
		self.lines[#self.lines] = string.rep("\t", depth) .. 'New "' .. inst.ClassName .. '" {}'
		return
	end
	self.lines[#self.lines] = string.rep("\t", depth) .. header
	for _, e in entries do self:line(depth + 1, e .. ",") end
	if #children > 0 then
		self:line(depth + 1, "[Children] = {")
		for _, child in children do
			self:object(child, depth + 2)
			self.lines[#self.lines] ..= ","
		end
		self:line(depth + 1, "},")
	end
	self:line(depth, "}")
end

-- Public API ------------------------------------------------------------------------------------------

function Exporter.CanExport(inst)
	return CLASSES[inst.ClassName] ~= nil
end

-- roots: list of ScreenGuis / GuiObjects. options: { loader = "github" | "pinned" | "file", buttonStubs = bool }
-- Returns source, warnings.
function Exporter.Export(roots, options)
	options = options or {}
	local w = newWriter(options)
	local loose = {}
	local body = {}
	local guiVars = {}
	for _, root in roots do
		if root:IsA("ScreenGui") then
			local name = root.Name:gsub("[^%w_]", "")
			if name == "" or name:match("^%d") then name = "Gui" .. (#guiVars + 1) end
			while guiVars[name] do name ..= "_" end
			guiVars[name] = true
			w.lines = {}
			w:object(root, 0)
			w.lines[1] = "local " .. name .. " = " .. w.lines[1]
			table.insert(body, table.concat(w.lines, "\n"))
		elseif CLASSES[root.ClassName] then
			table.insert(loose, root)
		end
	end
	if #loose > 0 then
		w.lines = {}
		w:line(0, 'local gui = New "ScreenGui" {')
		w:line(1, "[Children] = {")
		for _, root in loose do
			w:object(root, 2)
			w.lines[#w.lines] ..= ","
		end
		w:line(1, "},")
		w:line(0, "}")
		table.insert(body, table.concat(w.lines, "\n"))
	end

	local out = {}
	table.insert(out, "-- Exported from Roblox Studio with the Drawui exporter.")
	if #w.warnings > 0 then
		table.insert(out, "-- Notes (not exported or drawn differently):")
		for _, text in w.warnings do table.insert(out, "--   " .. text) end
	end
	table.insert(out, Exporter.Loaders[options.loader or "github"] or Exporter.Loaders.github)
	table.insert(out, "local New, Children = UI.New, UI.Children")
	table.insert(out, "")
	table.insert(out, table.concat(body, "\n\n"))
	return table.concat(out, "\n") .. "\n", w.warnings
end

return Exporter
