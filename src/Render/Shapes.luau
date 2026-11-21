-- Render/Shapes: rounded rectangles, rings (strokes/borders) and gradient fills.
--
-- Potassium anti-aliases every Quad/Triangle/Circle on its own, so two primitives that merely
-- touch leave a faint seam along the shared edge. Two rules keep shapes seamless:
--   1. Boxes are snapped to whole pixels: axis-aligned edges then fall on pixel boundaries,
--      where anti-aliasing adds no partial coverage.
--   2. Opaque shapes are built from OVERLAPPING pieces (4 corner Circles + a cross of 2 Squares,
--      gradient bands overlapping by 1px). Overlap is invisible when opaque.
--   Translucent shapes cannot overlap (alpha would double), so they use exact, disjoint pieces.
return function(UI, ctx)
    local U = ctx.U
    local clamp = U.clamp
    local HALF_PI = math.pi / 2
    local OPAQUE = 0.999

    -- Even segment count per 90° corner, so corner fans pack into Quads.
    local function segmentsFor(radius)
        if radius < 1 then return 0 end
        return 2 * clamp(math.ceil(radius / 8), 1, 4)
    end
    ctx.segmentsFor = segmentsFor

    local function snapBox(pos, size)
        local x0, y0 = math.floor(pos.X + 0.5), math.floor(pos.Y + 0.5)
        local x1, y1 = math.floor(pos.X + size.X + 0.5), math.floor(pos.Y + size.Y + 0.5)
        return Vector2.new(x0, y0), Vector2.new(math.max(0, x1 - x0), math.max(0, y1 - y0))
    end
    ctx.snapBox = snapBox
    local function snapRadius(radius, size)
        return math.min(math.floor(radius + 0.5), math.floor(math.min(size.X, size.Y) / 2))
    end

    local function centers(pos, size, r)
        local x0, y0, x1, y1 = pos.X, pos.Y, pos.X + size.X, pos.Y + size.Y
        return { Vector2.new(x0 + r, y0 + r), Vector2.new(x1 - r, y0 + r), Vector2.new(x1 - r, y1 - r), Vector2.new(x0 + r, y1 - r) }
    end
    -- Box corner matching centers(): TL, TR, BR, BL.
    local function boxCorners(pos, size)
        return { pos, pos + Vector2.new(size.X, 0), pos + size, pos + Vector2.new(0, size.Y) }
    end
    local function arc(c, r, angle) return c + Vector2.new(math.cos(angle), math.sin(angle)) * r end

    -- Clockwise outline of a rounded rect: 4 * (segs + 1) points (4 when segs == 0).
    function ctx.outline(pos, size, radius, segs)
        radius = clamp(radius, 0, math.min(size.X, size.Y) / 2)
        if segs <= 0 then radius = 0 end
        local pts = {}
        for i, c in ipairs(centers(pos, size, radius)) do
            local base = math.pi + (i - 1) * HALF_PI
            if segs <= 0 then table.insert(pts, c)
            else for j = 0, segs do table.insert(pts, arc(c, radius, base + j * HALF_PI / segs)) end end
        end
        return pts
    end

    -- Exact corner fans (disjoint Quads); colorFn(i, quadPoints) -> color, opacity.
    local function cornerFans(n, pos, size, r, clip, colorFn)
        local segs = segmentsFor(r)
        local step = HALF_PI / segs
        for i, c in ipairs(centers(pos, size, r)) do
            local base = math.pi + (i - 1) * HALF_PI
            local prev = arc(c, r, base)
            for j = 2, segs, 2 do
                local nextPoint = arc(c, r, base + j * step)
                local pts = { c, prev, arc(c, r, base + (j - 1) * step), nextPoint }
                local color, opacity = colorFn(i, pts)
                ctx.convex(n, pts, color, opacity, clip)
                prev = nextPoint
            end
        end
    end
    local function circleSides(r) return clamp(math.ceil(r * 1.5), 12, 64) end
    local function cornerCircle(n, c, r, color, opacity)
        if ctx.transform then c = ctx.applyTransform(ctx.transform, c) end
        ctx.primitive(n, "Circle", { Position = c, Radius = r, Color = color, Transparency = opacity,
            Filled = true, NumSides = circleSides(r), Thickness = 1 })
    end
    -- Circles cannot be clipped, so the overlapping path is used only when fully visible.
    local function canOverlap(pos, size, opacity, clip)
        if opacity < OPAQUE or not ctx.fullyInside(ctx.rect(pos, size), clip) then return false end
        local t = ctx.transform
        if not t then return true end
        for _, p in ipairs(boxCorners(pos, size)) do
            if not ctx.contains(ctx.screenClip, ctx.applyTransform(t, p)) then return false end
        end
        return true
    end

    -- Solid rounded rect.
    function ctx.fillRounded(n, pos, size, radius, color, opacity, clip)
        if opacity <= 0 then return end
        pos, size = snapBox(pos, size)
        if size.X <= 0 or size.Y <= 0 then return end
        local r = snapRadius(radius, size)
        if r < 1 then ctx.square(n, pos, size, color, opacity, clip); return end
        local w, h = size.X, size.Y
        opacity = clamp(opacity, 0, 1)
        if canOverlap(pos, size, opacity, clip) then
            for _, c in ipairs(centers(pos, size, r)) do cornerCircle(n, c, r, color, opacity) end
            ctx.square(n, pos + Vector2.new(r, 0), Vector2.new(w - 2 * r, h), color, opacity, clip)
            ctx.square(n, pos + Vector2.new(0, r), Vector2.new(w, h - 2 * r), color, opacity, clip)
            return
        end
        ctx.square(n, pos + Vector2.new(r, 0), Vector2.new(w - 2 * r, h), color, opacity, clip)
        ctx.square(n, pos + Vector2.new(0, r), Vector2.new(r, h - 2 * r), color, opacity, clip)
        ctx.square(n, pos + Vector2.new(w - r, r), Vector2.new(r, h - 2 * r), color, opacity, clip)
        cornerFans(n, pos, size, r, clip, function() return color, opacity end)
    end

    -- Gradient description from a UIGradient (see Modifiers/UIGradient).
    function ctx.gradientAt(g, t)
        local shifted = t - g.Shift
        return U.sample(g.Colors, shifted), 1 - U.sample(g.Transparency, shifted)
    end

    -- Rounded rect filled with a gradient. Body rects are cut into bands along the gradient:
    -- for 0/90/180/270° they are pixel-snapped Squares sharing exact edges; other angles use
    -- clipped polygons (overlapping by 1px when opaque). Corners take the colour at their centroid.
    function ctx.fillGradient(n, pos, size, radius, g, baseColor, opacity, clip)
        pos, size = snapBox(pos, size)
        local w, h = size.X, size.Y
        if w <= 0 or h <= 0 then return end
        local r = snapRadius(radius, size)
        if r < 1 then r = 0 end
        local angle = math.rad(g.Rotation)
        local dx, dy = math.cos(angle), math.sin(angle)
        if math.abs(dx) < 1e-6 then dx = 0 end
        if math.abs(dy) < 1e-6 then dy = 0 end
        local lo, hi = math.huge, -math.huge
        for _, p in ipairs(boxCorners(pos, size)) do
            local d = p.X * dx + p.Y * dy
            lo = math.min(lo, d); hi = math.max(hi, d)
        end
        local length = hi - lo
        if length <= 0 then return end
        local function shade(point)
            local color, alpha = ctx.gradientAt(g, (point.X * dx + point.Y * dy - lo) / length)
            return U.multiply(baseColor, color), clamp(opacity * alpha, 0, 1)
        end
        local overlap = g.Opaque and canOverlap(pos, size, opacity, clip)
        local bands = clamp(math.ceil(length / 4), 4, 64)
        local axisX, axisY = dy == 0, dx == 0
        local boxStart = axisX and pos.X or pos.Y
        local boxLength = axisX and w or h
        local function edge(i) -- pixel-snapped band boundary along the axis
            return math.floor(boxStart + boxLength * clamp(i, 0, bands) / bands + 0.5)
        end
        local function fillRect(p0, s0)
            if s0.X <= 0 or s0.Y <= 0 then return end
            if axisX or axisY then
                local from = axisX and p0.X or p0.Y
                local to = from + (axisX and s0.X or s0.Y)
                for i = 0, bands - 1 do
                    local a, b = math.max(edge(i), from), math.min(edge(i + 1), to)
                    if b > a then
                        local bandPos = axisX and Vector2.new(a, p0.Y) or Vector2.new(p0.X, a)
                        local bandSize = axisX and Vector2.new(b - a, s0.Y) or Vector2.new(s0.X, b - a)
                        local color, alpha = shade(bandPos + bandSize / 2)
                        ctx.square(n, bandPos, bandSize, color, alpha, clip)
                    end
                end
            else
                local shape = { p0, p0 + Vector2.new(s0.X, 0), p0 + s0, p0 + Vector2.new(0, s0.Y) }
                for i = 0, bands - 1 do
                    local a, b = lo + length * i / bands, lo + length * (i + 1) / bands
                    if overlap and i < bands - 1 then b += 1 end
                    local piece = ctx.clipHalf(ctx.clipHalf(shape, dx, dy, a), -dx, -dy, -b)
                    if #piece >= 3 then
                        local sum = U.ZERO
                        for _, p in ipairs(piece) do sum += p end
                        local color, alpha = shade(sum / #piece)
                        ctx.convex(n, piece, color, alpha, clip)
                    end
                end
            end
        end
        if r == 0 then fillRect(pos, size); return end
        local corners = boxCorners(pos, size)
        if overlap then
            for i, c in ipairs(centers(pos, size, r)) do
                local color, alpha = shade((c + corners[i]) / 2)
                cornerCircle(n, c, r, color, alpha)
            end
            fillRect(pos + Vector2.new(r, 0), Vector2.new(w - 2 * r, h))
            fillRect(pos + Vector2.new(0, r), Vector2.new(w, h - 2 * r))
            return
        end
        fillRect(pos + Vector2.new(r, 0), Vector2.new(w - 2 * r, h))
        fillRect(pos + Vector2.new(0, r), Vector2.new(r, h - 2 * r))
        fillRect(pos + Vector2.new(w - r, r), Vector2.new(r, h - 2 * r))
        cornerFans(n, pos, size, r, clip, function(_, pts)
            return shade((pts[1] + pts[2] + pts[3] + pts[4]) / 4)
        end)
    end

    -- Background fill entry point used by the renderer.
    function ctx.fillShape(n, pos, size, radius, color, opacity, clip, gradient)
        if opacity <= 0 or size.X <= 0 or size.Y <= 0 then return end
        if gradient and not gradient.Constant then
            ctx.fillGradient(n, pos, size, radius, gradient, color, opacity, clip)
            return
        end
        if gradient then
            local c, a = ctx.gradientAt(gradient, 0)
            color, opacity = U.multiply(color, c), opacity * a
        end
        ctx.fillRounded(n, pos, size, radius, color, opacity, clip)
    end

    -- Ring between two offsets (d0 < d1, in pixels, negative = inside) of a rounded rect.
    -- roundJoin rounds the outer corners of a sharp rect (UIStroke LineJoinMode.Round).
    function ctx.ring(n, pos, size, radius, d0, d1, color, opacity, clip, roundJoin)
        if opacity <= 0 or d1 <= d0 then return end
        pos, size = snapBox(pos, size)
        radius = clamp(radius, 0, math.min(size.X, size.Y) / 2)
        local function box(d)
            local r
            if radius > 0 then r = math.max(0, radius + d) elseif roundJoin then r = math.max(0, d) else r = 0 end
            return pos - Vector2.new(d, d), Vector2.new(math.max(0, size.X + 2 * d), math.max(0, size.Y + 2 * d)), r
        end
        local p0, s0, r0 = box(d0)
        local p1, s1, r1 = box(d1)
        local segs = segmentsFor(math.max(r0, r1))
        -- outline() zeroes the radius when segs is 0; keep counts equal by passing the same segs.
        local inner, outer = ctx.outline(p0, s0, r0, segs), ctx.outline(p1, s1, r1, segs)
        local count = #inner
        for i = 1, count do
            local j = i % count + 1
            ctx.convex(n, { inner[i], outer[i], outer[j], inner[j] }, color, opacity, clip)
        end
    end
end
