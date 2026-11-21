-- Modifiers/UICorner: rounds the parent's background, border, strokes, gradient, image and hit area.
-- CornerRadius.Scale is relative to the parent's shorter side (0.5 = pill / circle).
-- Accepts a number as shorthand for UDim.new(0, number).
return function(UI, ctx)
    local U = ctx.U
    UI.RegisterClass("UICorner", {
        Base = "UIComponent",
        Defaults = function(p) p.CornerRadius = UDim.new(0, 8) end,
        Coerce = { CornerRadius = U.toUDim },
        Style = function(m, n, style)
            local s = style.size
            style.radius = math.max(0, U.udim(m._p.CornerRadius, math.min(s.X, s.Y), n._scale))
        end,
    })
end
