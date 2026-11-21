-- Modifiers/UIStroke: outline around the parent.
--   ApplyStrokeMode      "Contextual" (text objects: outline the text) | "Border" (always the box)
--   BorderStrokePosition "Outer" | "Center" | "Inner"
--   LineJoinMode         "Round" | "Miter" | "Bevel" (Round rounds outer corners of sharp boxes)
-- Drawn as a ring of Quads, so translucent strokes have no overlapping seams.
return function(UI, ctx)
    local U = ctx.U
    local function isContextualText(m, n)
        return n._class.IsText and U.enumName(m._p.ApplyStrokeMode) ~= "Border"
    end
    UI.RegisterClass("UIStroke", {
        Base = "UIComponent",
        Defaults = function(p)
            p.Color = Color3.fromRGB(75, 82, 103); p.Thickness = 1; p.Transparency = 0; p.Enabled = true
            p.ApplyStrokeMode = "Contextual"; p.BorderStrokePosition = "Outer"; p.LineJoinMode = "Round"
        end,
        Style = function(m, n, style)
            if isContextualText(m, n) then
                style.textStroke = { Color = U.multiply(m._p.Color, style.tint), Transparency = m._p.Transparency }
            end
        end,
        Overlay = function(m, n, style)
            if isContextualText(m, n) then return end
            local p = m._p
            local t = p.Thickness * n._scale
            if t <= 0 then return end
            local position = U.enumName(p.BorderStrokePosition)
            local d0, d1 = 0, t
            if position == "Center" then d0, d1 = -t / 2, t / 2
            elseif position == "Inner" then d0, d1 = -t, 0 end
            ctx.ring(n, style.pos, style.size, style.radius, d0, d1, U.multiply(p.Color, style.tint),
                style.opacity * (1 - p.Transparency), style.clip, U.enumName(p.LineJoinMode) == "Round")
        end,
    })
end
