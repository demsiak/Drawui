-- Render/Pool: persistent Drawing object pool + clipped primitives.
-- Every node owns its Drawing objects; only changed properties are written to the renderer.
-- Clipping is done in software: rects are intersected, polygons are cut with Sutherland-Hodgman,
-- so rounded corners, strokes and gradients clip exactly (no scissor API in Drawing).
return function(UI, ctx)
    local U = ctx.U
    local clamp = U.clamp
    ctx.z = 0

    local function drawing(n, key, kind, props)
        local e = n._draws[key]
        if not e then e = { object = Drawing.new(kind), props = {} }; n._draws[key] = e end
        e.used = true
        local cache, object = e.props, e.object
        for property, value in pairs(props) do
            if cache[property] ~= value then object[property] = value; cache[property] = value end
        end
        return object
    end
    ctx.drawing = drawing

    -- Pool keys are per kind ("Quad3"), so a node reuses objects even when its shape mix changes.
    local function primitive(n, kind, props)
        local i = (n._counts[kind] or 0) + 1
        n._counts[kind] = i
        ctx.z += 1
        props.ZIndex = ctx.z
        props.Visible = true
        return drawing(n, kind .. i, kind, props)
    end
    ctx.primitive = primitive

    -- Rect helpers ------------------------------------------------------------------------------
    local function rect(pos, size) return { x = pos.X, y = pos.Y, r = pos.X + size.X, b = pos.Y + size.Y } end
    local function intersect(a, b)
        return { x = math.max(a.x, b.x), y = math.max(a.y, b.y), r = math.min(a.r, b.r), b = math.min(a.b, b.b) }
    end
    local function nonempty(r) return r.r > r.x and r.b > r.y end
    local function contains(r, p) return p.X >= r.x and p.Y >= r.y and p.X < r.r and p.Y < r.b end
    local function fullyInside(a, b) return a.x >= b.x and a.y >= b.y and a.r <= b.r and a.b <= b.b end
    ctx.rect, ctx.intersect, ctx.nonempty, ctx.contains, ctx.fullyInside = rect, intersect, nonempty, contains, fullyInside

    -- Filled axis-aligned rectangle.
    function ctx.square(n, pos, size, color, opacity, clip)
        local r = intersect(rect(pos, size), clip)
        if opacity <= 0 or not nonempty(r) then return end
        primitive(n, "Square", { Position = Vector2.new(r.x, r.y), Size = Vector2.new(r.r - r.x, r.b - r.y),
            Color = color, Transparency = clamp(opacity, 0, 1), Filled = true, Thickness = 1 })
    end

    -- Line clipped with Liang-Barsky.
    function ctx.line(n, a, b, color, opacity, thickness, clip)
        if opacity <= 0 then return end
        local delta, low, high = b - a, 0, 1
        local function edge(p, q)
            if p == 0 then return q >= 0 end
            local t = q / p
            if p < 0 then low = math.max(low, t) else high = math.min(high, t) end
            return low <= high
        end
        if not edge(-delta.X, a.X - clip.x) or not edge(delta.X, clip.r - a.X)
            or not edge(-delta.Y, a.Y - clip.y) or not edge(delta.Y, clip.b - a.Y) then return end
        primitive(n, "Line", { From = a + delta * low, To = a + delta * high, Color = color,
            Transparency = clamp(opacity, 0, 1), Thickness = thickness })
    end

    -- Convex polygons -----------------------------------------------------------------------------
    -- Keeps the part of `pts` where dot(p, (dx, dy)) >= c.
    local function clipHalf(pts, dx, dy, c)
        local out, count = {}, #pts
        if count == 0 then return out end
        local prev = pts[count]
        local prevD = prev.X * dx + prev.Y * dy - c
        for i = 1, count do
            local cur = pts[i]
            local curD = cur.X * dx + cur.Y * dy - c
            if curD >= 0 then
                if prevD < 0 then table.insert(out, prev + (cur - prev) * (prevD / (prevD - curD))) end
                table.insert(out, cur)
            elseif prevD >= 0 then
                table.insert(out, prev + (cur - prev) * (prevD / (prevD - curD)))
            end
            prev, prevD = cur, curD
        end
        return out
    end
    ctx.clipHalf = clipHalf
    local function clipRect(pts, r)
        pts = clipHalf(pts, 1, 0, r.x); pts = clipHalf(pts, -1, 0, -r.r)
        pts = clipHalf(pts, 0, 1, r.y); pts = clipHalf(pts, 0, -1, -r.b)
        return pts
    end
    local function bounds(pts)
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for _, p in ipairs(pts) do
            x0 = math.min(x0, p.X); y0 = math.min(y0, p.Y); x1 = math.max(x1, p.X); y1 = math.max(y1, p.Y)
        end
        return { x = x0, y = y0, r = x1, b = y1 }
    end
    local function area(pts)
        local sum, count = 0, #pts
        for i = 1, count do
            local a, b = pts[i], pts[i % count + 1]
            sum += a.X * b.Y - b.X * a.Y
        end
        return math.abs(sum) / 2
    end

    local function triangle(n, a, b, c, color, opacity)
        primitive(n, "Triangle", { PointA = a, PointB = b, PointC = c, Color = color, Transparency = opacity, Filled = true, Thickness = 1 })
    end
    local function quad(n, a, b, c, d, color, opacity)
        primitive(n, "Quad", { PointA = a, PointB = b, PointC = c, PointD = d, Color = color, Transparency = opacity, Filled = true, Thickness = 1 })
    end
    local EPS = 1e-4
    local function same(a, b) return math.abs(a - b) < EPS end
    -- Drops consecutive (cyclic) duplicate vertices left by clipping and degenerate arcs.
    local function dedupe(pts)
        local out = {}
        for _, p in ipairs(pts) do
            local last = out[#out]
            if not last or not (same(last.X, p.X) and same(last.Y, p.Y)) then table.insert(out, p) end
        end
        while #out > 1 and same(out[1].X, out[#out].X) and same(out[1].Y, out[#out].Y) do table.remove(out) end
        return out
    end
    local function emit(n, pts, color, opacity)
        local count = #pts
        if count == 4 then
            local a, b, c, d = pts[1], pts[2], pts[3], pts[4]
            -- Axis-aligned rectangles go to Square: cheaper and pixel-crisp.
            if (same(a.Y, b.Y) and same(b.X, c.X) and same(c.Y, d.Y) and same(d.X, a.X))
                or (same(a.X, b.X) and same(b.Y, c.Y) and same(c.X, d.X) and same(d.Y, a.Y)) then
                primitive(n, "Square", { Position = Vector2.new(math.min(a.X, c.X), math.min(a.Y, c.Y)),
                    Size = Vector2.new(math.abs(c.X - a.X), math.abs(c.Y - a.Y)),
                    Color = color, Transparency = opacity, Filled = true, Thickness = 1 })
            else
                quad(n, a, b, c, d, color, opacity)
            end
            return
        end
        if count == 3 then triangle(n, pts[1], pts[2], pts[3], color, opacity); return end
        -- Fan from the first vertex, two segments per Quad.
        local first, i = pts[1], 2
        while i < count do
            if i + 2 <= count then quad(n, first, pts[i], pts[i + 1], pts[i + 2], color, opacity); i += 2
            else triangle(n, first, pts[i], pts[i + 1], color, opacity); i += 1 end
        end
    end

    -- Draws a filled convex polygon, clipped to `clip`.
    function ctx.convex(n, pts, color, opacity, clip)
        if opacity <= 0 or #pts < 3 then return end
        local b = bounds(pts)
        if not fullyInside(b, clip) then
            if not nonempty(intersect(b, clip)) then return end
            pts = clipRect(pts, clip)
        end
        pts = dedupe(pts)
        if #pts < 3 or area(pts) < 0.05 then return end
        emit(n, pts, color, clamp(opacity, 0, 1))
    end
end
