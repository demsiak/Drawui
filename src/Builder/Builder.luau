-- Builder/Builder: declarative construction on top of UI.new.
--
--   local New, Children, OnEvent, OnChange = UI.New, UI.Children, UI.OnEvent, UI.OnChange
--   local card = New "Frame" {
--       Size = UDim2.fromOffset(240, 120),
--       Corner = 10,                                  -- sugar: UICorner
--       Stroke = { Color = Color3.new(1, 1, 1), Transparency = 0.8 },
--       Gradient = { Color3.fromRGB(40, 44, 60), Color3.fromRGB(26, 28, 38) },
--       Shadow = true,
--       Padding = 12,
--       [Children] = {
--           Title = New "TextLabel" { Text = "Hello", Size = UDim2.new(1, 0, 0, 20) },  -- key = Name
--           New "TextButton" { Text = "Go", Activated = function() print("go") end },   -- event shorthand
--       },
--       [OnChange "AbsoluteSize"] = function(size) end,
--       [UI.Ref] = function(node) myCard = node end,
--   }
--
-- Sugar keys are pluggable: UI.RegisterSugar(name, function(node, value) ... end).
return function(UI, ctx)
    local U = ctx.U
    local Builder = {}
    UI.Builder = Builder

    local function marker(name) return setmetatable({}, { __tostring = function() return name end }) end
    local CHILDREN, REF = marker("UI.Children"), marker("UI.Ref")
    Builder.Children, Builder.Ref = CHILDREN, REF
    UI.Children, UI.Ref = CHILDREN, REF

    local eventKeys, changeKeys = {}, {}
    function Builder.OnEvent(name)
        if not eventKeys[name] then eventKeys[name] = { kind = "event", name = name } end
        return eventKeys[name]
    end
    function Builder.OnChange(property)
        if not changeKeys[property] then changeKeys[property] = { kind = "change", name = property } end
        return changeKeys[property]
    end
    UI.OnEvent, UI.OnChange = Builder.OnEvent, Builder.OnChange

    local sugar = {}
    function Builder.RegisterSugar(key, fn)
        assert(type(key) == "string" and type(fn) == "function", "RegisterSugar(name, function(node, value))")
        sugar[key] = fn
    end
    UI.RegisterSugar = Builder.RegisterSugar

    local function addChildren(node, list)
        if ctx.isLive(list) then list.Parent = node; return end
        assert(type(list) == "table", "[Children] expects an object or a list of objects")
        for _, c in ipairs(list) do addChildren(node, c) end
        local named = {}
        for key in pairs(list) do if type(key) == "string" then table.insert(named, key) end end
        table.sort(named)
        for _, key in ipairs(named) do
            local c = list[key]
            assert(ctx.isLive(c), "[Children]." .. key .. " must be a UI object")
            c.Name = key
            c.Parent = node
        end
    end

    local function apply(node, props)
        local parent
        local deferred = {}
        for key, value in pairs(props) do
            if key == "Parent" then parent = value
            elseif type(key) == "string" then
                if node._p[key] ~= nil then node[key] = value
                elseif ctx.eventNames[key] and type(value) == "function" then node[key]:Connect(value)
                elseif sugar[key] then table.insert(deferred, { sugar[key], value })
                else node[key] = value end -- raises "Unsupported property"
            elseif key == CHILDREN then table.insert(deferred, { addChildren, value })
            elseif key == REF then table.insert(deferred, { function(n, v)
                if type(v) == "function" then v(n) else v.value = n end
            end, value })
            elseif type(key) == "table" and key.kind == "event" then node[key.name]:Connect(value)
            elseif type(key) == "table" and key.kind == "change" then
                local name = key.name
                node:GetPropertyChangedSignal(name):Connect(function() value(node[name]) end)
            else error("Unsupported builder key: " .. tostring(key)) end
        end
        for _, d in ipairs(deferred) do d[1](node, d[2]) end
        if parent then node.Parent = parent end
    end

    -- New "Class" { props } -> object
    function Builder.New(class)
        return function(props)
            local node = UI.new(class)
            local ok, err = pcall(apply, node, props or {})
            if not ok then node:Destroy(); error(err, 2) end
            return node
        end
    end
    UI.New = Builder.New

    -- Hydrate "existing" { props }: apply builder props to an object that already exists.
    function Builder.Hydrate(node)
        assert(ctx.isLive(node), "Hydrate expects a live UI object")
        return function(props) apply(node, props or {}); return node end
    end
    UI.Hydrate = Builder.Hydrate

    -- Built-in sugar -------------------------------------------------------------------------------
    local function make(class, node, props)
        props.Parent = node
        return UI.new(class, props)
    end
    local function propsOr(value, primary)
        if typeof(value) == "table" and getmetatable(value) == nil and value[1] == nil then return table.clone(value) end
        return { [primary] = value }
    end

    Builder.RegisterSugar("Corner", function(node, v) make("UICorner", node, propsOr(v, "CornerRadius")) end)
    Builder.RegisterSugar("Stroke", function(node, v)
        if v == true then v = {} end
        local props
        if typeof(v) == "Color3" then props = { Color = v }
        elseif type(v) == "number" then props = { Thickness = v }
        else props = table.clone(v) end
        make("UIStroke", node, props)
    end)
    Builder.RegisterSugar("Gradient", function(node, v)
        local props
        if type(v) == "table" and getmetatable(v) == nil and (v.Color ~= nil or v.Rotation ~= nil or v.Transparency ~= nil or v.Offset ~= nil) then
            props = table.clone(v)
        else props = { Color = v } end
        make("UIGradient", node, props)
    end)
    Builder.RegisterSugar("Shadow", function(node, v)
        make("UIShadow", node, v == true and {} or table.clone(v))
    end)
    Builder.RegisterSugar("Padding", function(node, v)
        local props = {}
        if type(v) == "number" or typeof(v) == "UDim" then
            for _, side in ipairs({ "Left", "Right", "Top", "Bottom" }) do props["Padding" .. side] = U.toUDim(v) end
        else
            for key, value in pairs(v) do
                if key == "Horizontal" then props.PaddingLeft = value; props.PaddingRight = value
                elseif key == "Vertical" then props.PaddingTop = value; props.PaddingBottom = value
                elseif string.sub(key, 1, 7) == "Padding" then props[key] = value
                else props["Padding" .. key] = value end
            end
        end
        make("UIPadding", node, props)
    end)
    Builder.RegisterSugar("Scale", function(node, v) make("UIScale", node, { Scale = v }) end)
    Builder.RegisterSugar("AspectRatio", function(node, v) make("UIAspectRatioConstraint", node, propsOr(v, "AspectRatio")) end)
    Builder.RegisterSugar("SizeLimit", function(node, v) make("UISizeConstraint", node, table.clone(v)) end)
    Builder.RegisterSugar("TextSizeLimit", function(node, v) make("UITextSizeConstraint", node, table.clone(v)) end)
    Builder.RegisterSugar("List", function(node, v) make("UIListLayout", node, v == true and {} or propsOr(v, "Padding")) end)
    Builder.RegisterSugar("Grid", function(node, v) make("UIGridLayout", node, v == true and {} or table.clone(v)) end)
end
