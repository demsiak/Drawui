-- Classes/ScrollingFrame: canvas sizing in PreChildren, scrollbar in DrawAfter.
-- Wheel and thumb dragging are handled in Input/Input.
return function(UI, ctx)
    local U = ctx.U
    local clamp = U.clamp
    UI.RegisterClass("ScrollingFrame", {
        Base = "GuiObject",
        ReadOnly = { AbsoluteCanvasSize = true },
        Defaults = function(p)
            p.CanvasSize = UDim2.new(); p.CanvasPosition = U.ZERO; p.AbsoluteCanvasSize = U.ZERO
            p.AutomaticCanvasSize = "Y"; p.ScrollingEnabled = true; p.ScrollingDirection = "Y"
            p.ScrollBarThickness = 5; p.ScrollBarImageColor3 = Color3.fromRGB(113, 125, 155)
            p.ScrollBarImageTransparency = 0.1; p.ClipsDescendants = true; p.Active = true
        end,
        Hittable = function() return true end,
        PreChildren = function(n, info)
            local p = n._p
            local explicit = U.vec(p.CanvasSize, info.size, info.scale)
            local pad = info.topLeft + info.bottomRight
            local canvas = Vector2.new(
                U.isAuto(p.AutomaticCanvasSize, "X") and math.max(explicit.X, info.content.X + pad.X) or explicit.X,
                U.isAuto(p.AutomaticCanvasSize, "Y") and math.max(explicit.Y, info.content.Y + pad.Y) or explicit.Y)
            ctx.changed(n, "AbsoluteCanvasSize", canvas)
            local cp, size = p.CanvasPosition, info.size
            ctx.changed(n, "CanvasPosition", Vector2.new(clamp(cp.X, 0, math.max(0, canvas.X - size.X)),
                clamp(cp.Y, 0, math.max(0, canvas.Y - size.Y))))
            info.origin -= p.CanvasPosition
        end,
        DrawAfter = function(n, style)
            local p = n._p
            local s = style.size
            if not ctx.nonempty(style.visible) or p.ScrollBarThickness <= 0 then return end
            local total = p.AbsoluteCanvasSize.Y
            if total <= s.Y or U.enumName(p.ScrollingDirection) == "X" then return end
            local thickness = p.ScrollBarThickness * n._scale
            local height = math.min(s.Y, math.max(18 * n._scale, s.Y * s.Y / total))
            local offset = p.CanvasPosition.Y / (total - s.Y) * (s.Y - height)
            local thumbPos, thumbSize = style.pos + Vector2.new(s.X - thickness - 2, offset), Vector2.new(thickness, height)
            ctx.fillRounded(n, thumbPos, thumbSize, thickness / 2, U.multiply(p.ScrollBarImageColor3, style.tint),
                style.opacity * (1 - p.ScrollBarImageTransparency), style.clip)
            table.insert(ctx.hits, { node = n, rect = ctx.intersect(ctx.rect(thumbPos, thumbSize), style.clip), scrollbar = true, height = height })
        end,
    })
end
