-- Core/Registry: every class (GuiObjects and UI modifiers) is a table of defaults + hooks,
-- registered with UI.RegisterClass. Adding a class never requires touching the core.
--
-- Class definition fields (all optional):
--   Base        parent class name; hooks and defaults are inherited
--   Abstract    cannot be created with UI.new
--   Gui         rendered object that can hold children
--   Root        top-level container (ScreenGui)
--   Modifier    child that changes its parent (UICorner, UIStroke, ...)
--   Defaults    table or function(props) adding default properties
--   ReadOnly    { PropName = true } properties set only by the library
--   Coerce      { PropName = function(value) -> value } input normalisation
--   GuiObject hooks: Style(n, style, ctx), Draw(n, style, ctx), DrawAfter(n, style, ctx),
--                    PreChildren(n, info), Hittable(n) -> bool
--   Modifier hooks:  Style(m, n, style, ctx), Underlay(m, n, style, ctx), Overlay(m, n, style, ctx),
--                    ScaleFactor(m) -> number, AdjustSize(m, n, size) -> size (sorted by Order),
--                    Padding(m, n, size, scale) -> topLeft, bottomRight,
--                    Arrange(m, n, children, inner, scale) -> placements, contentSize,
--                    TextSizeLimits(m, n) -> min, max
return function(UI, ctx)
    local classes = {}
    ctx.classes = classes
    ctx.readonly = { ClassName = true, AbsolutePosition = true, AbsoluteSize = true }

    function UI.RegisterClass(name, def)
        assert(type(name) == "string" and type(def) == "table", "RegisterClass(name, definition)")
        local base = def.Base and classes[def.Base]
        assert(def.Base == nil or base, "Unknown base class: " .. tostring(def.Base))
        def.ClassName = name
        def.Chain = base and table.clone(base.Chain) or {}
        table.insert(def.Chain, def)
        def.Is = base and table.clone(base.Is) or {}
        def.Is[name] = true
        for key in pairs(def.ReadOnly or {}) do ctx.readonly[key] = true end
        if base then
            for _, key in ipairs({ "Abstract", "Root" }) do if def[key] == nil then def[key] = false end end
            setmetatable(def, { __index = base })
        end
        classes[name] = def
        return def
    end
    function UI.GetClass(name) return classes[name] end
    function UI.GetClasses()
        local out = {}
        for name, def in pairs(classes) do if not def.Abstract then table.insert(out, name) end end
        table.sort(out)
        return out
    end

    function ctx.defaults(def)
        local p = {}
        for _, d in ipairs(def.Chain) do
            local defaults = rawget(d, "Defaults")
            if type(defaults) == "function" then defaults(p)
            elseif defaults then for k, v in pairs(defaults) do p[k] = v end end
        end
        p.ClassName = def.ClassName
        p.Name = def.ClassName
        return p
    end

    -- First enabled modifier child implementing `hook` (Roblox honours one modifier per class).
    function ctx.modifier(n, hook)
        for _, c in ipairs(n._children) do
            local def = c._class
            if def.Modifier and def[hook] and c._p.Enabled ~= false then return c, def[hook] end
        end
    end
    -- Every enabled modifier implementing `hook`, first instance of each class only.
    function ctx.eachModifier(n, hook, fn)
        local seen
        for _, c in ipairs(n._children) do
            local def = c._class
            if def.Modifier and def[hook] and c._p.Enabled ~= false then
                seen = seen or {}
                if not seen[def] then seen[def] = true; fn(c, def[hook]) end
            end
        end
    end
end
