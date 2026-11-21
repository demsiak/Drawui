-- Modifiers/UIShadow: Roblox's UIShadow.
--   Color, Transparency, Enabled
--   BlurRadius        UDim (scale relative to the parent's shorter side); a number means pixels
--   Offset, Spread    UDim2 (relative to the parent's size); a Vector2 / number means pixels
--   Inset             true = inner shadow drawn inside the parent's shape
--   Mode              "Shape" (shadow of the box) or "Text" (drop shadow under the parent's text)
--   ShowBehindParent  false draws a Shape shadow over the parent's background
-- Blur is built from stacked translucent rounded rects whose combined opacity is 1 - Transparency.
-- Drawing text can't blur, so Text-mode shadows ignore BlurRadius.
return function(UI, ctx)
    local U = ctx.U

    local function toUDim2(v)
        if type(v) == "number" then return UDim2.fromOffset(v, v) end
        if typeof(v) == "Vector2" then return UDim2.fromOffset(v.X, v.Y) end
        return v
    end

    local function metrics(m, n, style)
        local p, s, scale = m._p, style.size, n._scale
        return math.max(0, U.udim(p.BlurRadius, math.min(s.X, s.Y), scale)), U.vec(p.Offset, s, scale), U.vec(p.Spread, s, scale)
    end
    local function layersFor(blur) return blur < 1 and 1 or U.clamp(math.ceil(blur / 2.5), 2, 10) end
    local function perLayer(total, layers) return 1 - (1 - math.min(total, 0.999)) ^ (1 / layers) end

    local function outer(m, n, style)
        local p = m._p
        local total = style.opacity * (1 - p.Transparency)
        if total <= 0 then return end
        local blur, offset, spread = metrics(m, n, style)
        local pos, size = style.pos + offset - spread, style.size + spread * 2
        if size.X <= 0 or size.Y <= 0 then return end
        local radius = style.radius > 0 and math.max(0, style.radius + math.max(spread.X, spread.Y)) or 0
        local color = U.multiply(p.Color, style.tint)
        local layers = layersFor(blur)
        local per = layers == 1 and total or perLayer(total, layers)
        -- Layers run from blur/2 inside the edge to blur/2 outside it, bunched towards the outside.
        for i = layers, 1, -1 do
            local f = layers == 1 and 0.5 or (i - 1) / (layers - 1)
            local grow = blur * (f * f - 0.5)
            local s = size + Vector2.new(grow * 2, grow * 2)
            if s.X > 0 and s.Y > 0 then
                ctx.fillRounded(n, pos - Vector2.new(grow, grow), s, math.max(0, radius + grow), color, per, style.clip)
            end
        end
    end

    local function inner(m, n, style)
        local p = m._p
        local total = style.opacity * (1 - p.Transparency)
        if total <= 0 then return end
        local blur, offset, spread = metrics(m, n, style)
        local clip = ctx.intersect(style.area, style.clip)
        if not ctx.nonempty(clip) then return end
        local far = math.max(style.size.X, style.size.Y) + math.abs(offset.X) + math.abs(offset.Y) + blur
        local color = U.multiply(p.Color, style.tint)
        local layers = layersFor(blur)
        local per = layers == 1 and total or perLayer(total, layers)
        local base = math.max(spread.X, spread.Y)
        -- Everything outside the shifted, shrunk inner box is in shadow; each layer shrinks further.
        for i = 1, layers do
            local f = layers == 1 and 0 or (i - 1) / (layers - 1)
            ctx.ring(n, style.pos + offset, style.size, style.radius, -(base + blur * f * f), far, color, per, clip, false)
        end
    end

    local function mode(m) return U.enumName(m._p.Mode) end

    UI.RegisterClass("UIShadow", {
        Base = "UIComponent",
        Defaults = function(p)
            p.Color = U.BLACK; p.Transparency = 0; p.Enabled = true
            p.BlurRadius = UDim.new(0, 0); p.Offset = UDim2.new(); p.Spread = UDim2.new()
            p.Inset = false; p.Mode = "Shape"; p.ShowBehindParent = true; p.ZIndex = -1
        end,
        Coerce = { BlurRadius = U.toUDim, Offset = toUDim2, Spread = toUDim2 },
        Style = function(m, n, style)
            if mode(m) ~= "Text" then return end
            local p = m._p
            style.textShadow = { Color = U.multiply(p.Color, style.tint), Opacity = 1 - p.Transparency,
                Offset = U.vec(p.Offset, style.size, n._scale) }
        end,
        Underlay = function(m, n, style)
            local p = m._p
            if mode(m) == "Shape" and not p.Inset and p.ShowBehindParent then outer(m, n, style) end
        end,
        Overlay = function(m, n, style)
            local p = m._p
            if mode(m) ~= "Shape" then return end
            if p.Inset then inner(m, n, style) elseif not p.ShowBehindParent then outer(m, n, style) end
        end,
    })
end
