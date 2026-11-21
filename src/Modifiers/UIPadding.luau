-- Modifiers/UIPadding: insets the parent's content area. Numbers are accepted as pixel offsets.
return function(UI, ctx)
    local U = ctx.U
    UI.RegisterClass("UIPadding", {
        Base = "UIComponent",
        Defaults = function(p)
            p.PaddingLeft = UDim.new(); p.PaddingRight = UDim.new()
            p.PaddingTop = UDim.new(); p.PaddingBottom = UDim.new()
        end,
        Coerce = { PaddingLeft = U.toUDim, PaddingRight = U.toUDim, PaddingTop = U.toUDim, PaddingBottom = U.toUDim },
        Padding = function(m, n, size, scale)
            local p = m._p
            return Vector2.new(U.udim(p.PaddingLeft, size.X, scale), U.udim(p.PaddingTop, size.Y, scale)),
                Vector2.new(U.udim(p.PaddingRight, size.X, scale), U.udim(p.PaddingBottom, size.Y, scale))
        end,
    })
end
