-- Modifiers/UIShadow (library extension, not a Roblox class): soft drop shadow behind the parent.
--   Color, Transparency (of the darkest part), Offset (Vector2 px), Blur (px), Spread (px), Enabled
-- Built from stacked translucent rounded rects whose combined opacity equals 1 - Transparency.
return function(UI, ctx)
    local U = ctx.U
    UI.RegisterClass("UIShadow", {
        Base = "UIComponent",
        Defaults = function(p)
            p.Color = U.BLACK; p.Transparency = 0.5; p.Offset = Vector2.new(0, 6)
            p.Blur = 18; p.Spread = 0; p.Enabled = true
        end,
        Underlay = function(m, n, style)
            local p = m._p
            local total = style.opacity * (1 - p.Transparency)
            if total <= 0 then return end
            local layers = U.clamp(math.ceil(p.Blur / 2.5), 1, 10)
            local per = 1 - (1 - math.min(total, 0.999)) ^ (1 / layers)
            local scale = n._scale
            local color = U.multiply(p.Color, style.tint)
            local base = style.pos + p.Offset * scale
            for i = layers, 1, -1 do
                -- Quadratic spacing: layers bunch up near the edge, so the falloff looks soft, not stepped.
                local f = (i - 1) / layers
                local grow = (p.Spread + p.Blur * f * f) * scale
                ctx.fillRounded(n, base - Vector2.new(grow, grow), style.size + Vector2.new(grow * 2, grow * 2),
                    style.radius + grow, color, per, style.clip)
            end
        end,
    })
end
