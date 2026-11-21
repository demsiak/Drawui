-- Modifiers/Constraints: UIScale, UIAspectRatioConstraint, UISizeConstraint, UITextSizeConstraint.
return function(UI, ctx)
    local U = ctx.U

    UI.RegisterClass("UIScale", {
        Base = "UIComponent",
        Defaults = { Scale = 1 },
        ScaleFactor = function(m) return m._p.Scale end,
    })

    UI.RegisterClass("UIAspectRatioConstraint", {
        Base = "UIConstraint", Order = 1,
        Defaults = { AspectRatio = 1, DominantAxis = "Width", AspectType = "FitWithinMaxSize" },
        AdjustSize = function(m, n, size)
            local ratio = m._p.AspectRatio
            if ratio <= 0 then return size end
            if U.enumName(m._p.DominantAxis) == "Height" then return Vector2.new(size.Y * ratio, size.Y) end
            return Vector2.new(size.X, size.X / ratio)
        end,
    })

    UI.RegisterClass("UISizeConstraint", {
        Base = "UIConstraint", Order = 2,
        Defaults = function(p) p.MinSize = U.ZERO; p.MaxSize = Vector2.new(math.huge, math.huge) end,
        AdjustSize = function(m, n, size)
            local p, s = m._p, n._scale
            return Vector2.new(U.clamp(size.X, p.MinSize.X * s, p.MaxSize.X * s), U.clamp(size.Y, p.MinSize.Y * s, p.MaxSize.Y * s))
        end,
    })

    -- Limits the size chosen by TextScaled.
    UI.RegisterClass("UITextSizeConstraint", {
        Base = "UIConstraint",
        Defaults = { MinTextSize = 1, MaxTextSize = 100 },
        TextSizeLimits = function(m, n)
            return m._p.MinTextSize * n._scale, m._p.MaxTextSize * n._scale
        end,
    })
end
