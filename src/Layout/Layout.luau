-- Layout/Layout: sizing and placement pass. Modifiers plug in through hooks:
--   ScaleFactor (UIScale), AdjustSize (aspect / size constraints), Padding (UIPadding),
--   Arrange (UIListLayout / UIGridLayout). Classes can hook PreChildren (text, scrolling).
return function(UI, ctx)
    local U = ctx.U
    local ZERO = U.ZERO

    function ctx.padding(n, size, scale)
        local m, fn = ctx.modifier(n, "Padding")
        if not m then return ZERO, ZERO end
        return fn(m, n, size, scale)
    end

    -- Visible GuiObject children in creation order.
    function ctx.guiChildren(n)
        local out = {}
        for _, c in ipairs(n._children) do if c._class.Gui and c._p.Visible then table.insert(out, c) end end
        return out
    end
    -- Visible GuiObject children in draw order (ZIndex, then creation order).
    function ctx.drawOrder(n)
        local out = ctx.guiChildren(n)
        table.sort(out, function(a, b)
            local x, y = a._p.ZIndex, b._p.ZIndex
            if x == y then return a._serial < b._serial end
            return x < y
        end)
        return out
    end
    -- Children sorted by a layout's SortOrder (LayoutOrder or Name).
    function ctx.sortForLayout(layout, children)
        local byName = U.enumName(layout._p.SortOrder) == "Name"
        table.sort(children, function(a, b)
            local x, y
            if byName then x, y = a._p.Name, b._p.Name else x, y = a._p.LayoutOrder, b._p.LayoutOrder end
            if x == y then return a._serial < b._serial end
            return x < y
        end)
        return children
    end

    function ctx.nodeSize(n, parentSize, inheritedScale)
        local own = 1
        ctx.eachModifier(n, "ScaleFactor", function(m, fn) own *= fn(m) end)
        own = math.max(0.001, own)
        n._ownScale = own
        n._scale = inheritedScale * own
        local p = n._p
        local size = U.vec(p.Size, parentSize, inheritedScale) * own
        if U.isAuto(p.AutomaticSize, "X") then size = Vector2.new(n._content.X, size.Y) end
        if U.isAuto(p.AutomaticSize, "Y") then size = Vector2.new(size.X, n._content.Y) end
        local adjusters = {}
        ctx.eachModifier(n, "AdjustSize", function(m, fn) table.insert(adjusters, { m, fn }) end)
        if #adjusters > 1 then
            table.sort(adjusters, function(a, b) return (a[1]._class.Order or 0) < (b[1]._class.Order or 0) end)
        end
        for _, a in ipairs(adjusters) do size = a[2](a[1], n, size) end
        return Vector2.new(math.max(0, size.X), math.max(0, size.Y))
    end

    -- Default placement: Position / AnchorPoint.
    local function freeArrange(n, children, inner, scale)
        local placements, content = {}, ZERO
        for _, c in ipairs(children) do
            local s = ctx.nodeSize(c, inner, scale)
            local anchor = c._p.AnchorPoint
            local p = U.vec(c._p.Position, inner, scale) - Vector2.new(anchor.X * s.X, anchor.Y * s.Y)
            placements[c] = { pos = p, size = s }
            content = Vector2.new(math.max(content.X, p.X + s.X), math.max(content.Y, p.Y + s.Y))
        end
        return placements, content
    end

    local function layoutNode(n, pos, size, scale, parentRotation)
        n._scale = scale
        ctx.changed(n, "AbsolutePosition", pos)
        ctx.changed(n, "AbsoluteSize", size)
        local rotation = (parentRotation or 0) + n._p.Rotation
        ctx.changed(n, "AbsoluteRotation", rotation)
        local tl, br = ctx.padding(n, size, scale)
        local inner = Vector2.new(math.max(0, size.X - tl.X - br.X), math.max(0, size.Y - tl.Y - br.Y))
        local children = ctx.guiChildren(n)
        local placements, content
        local layout, arrange = ctx.modifier(n, "Arrange")
        if layout then
            placements, content = arrange(layout, n, children, inner, scale)
            ctx.changed(layout, "AbsoluteContentSize", content)
        else
            placements, content = freeArrange(n, children, inner, scale)
        end
        local info = { pos = pos, size = size, inner = inner, topLeft = tl, bottomRight = br,
            origin = pos + tl, scale = scale, content = content }
        local pre = n._class.PreChildren
        if pre then pre(n, info) end
        for _, c in ipairs(children) do
            local item = placements[c]
            layoutNode(c, info.origin + item.pos, item.size, c._scale, rotation)
        end
        n._content = info.content + tl + br
    end
    ctx.layoutNode = layoutNode
end
