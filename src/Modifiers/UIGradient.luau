-- Modifiers/UIGradient: multiplies the parent's background (and text / image tint) by a gradient.
--   Color        ColorSequence, Color3, {Color3, Color3, ...} or {{time, Color3}, ...}
--   Transparency NumberSequence, number or list (same forms as Color)
--   Rotation     degrees, any angle (the shape is sliced into bands along the direction)
--   Offset       Vector2 shift in scale units along the gradient direction
--   ApplyToText  (extension) false keeps text / image colours untinted; true matches Roblox
return function(UI, ctx)
    local U = ctx.U
    UI.RegisterClass("UIGradient", {
        Base = "UIComponent",
        Defaults = function(p)
            p.Color = U.WHITE; p.Transparency = 0; p.Rotation = 0; p.Offset = U.ZERO; p.Enabled = true
            p.ApplyToText = true
        end,
        Style = function(m, n, style)
            local p = m._p
            local colors, transparency = U.keypoints(p.Color), U.keypoints(p.Transparency)
            local angle = math.rad(p.Rotation)
            style.gradient = {
                Colors = colors, Transparency = transparency, Rotation = p.Rotation,
                Shift = p.Offset.X * math.cos(angle) + p.Offset.Y * math.sin(angle),
                Constant = U.constant(colors) and U.constant(transparency),
                ApplyToText = p.ApplyToText,
                Opaque = (function()
                    for _, k in ipairs(transparency) do if k.Value > 0.001 then return false end end
                    return true
                end)(),
            }
        end,
    })
end
