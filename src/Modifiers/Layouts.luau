-- Modifiers/Layouts: UIListLayout (with Wraps) and UIGridLayout.
-- An Arrange hook returns { [child] = { pos = Vector2, size = Vector2 } } and the content size.
return function(UI, ctx)
    local U = ctx.U
    local ZERO = U.ZERO

    UI.RegisterClass("UIListLayout", {
        Base = "UILayout",
        Defaults = function(p) p.Padding = UDim.new(0, 0); p.Wraps = false end,
        Coerce = { Padding = U.toUDim },
        Arrange = function(layout, n, children, inner, scale)
            local p = layout._p
            local horizontal = U.enumName(p.FillDirection) == "Horizontal"
            ctx.sortForLayout(layout, children)
            local mainLimit = horizontal and inner.X or inner.Y
            local gap = U.udim(p.Padding, mainLimit, scale)
            local lines, line = {}, { items = {}, main = 0, cross = 0 }
            for _, c in ipairs(children) do
                local s = ctx.nodeSize(c, inner, scale)
                local main, cross = horizontal and s.X or s.Y, horizontal and s.Y or s.X
                if p.Wraps and #line.items > 0 and line.main + gap + main > mainLimit then
                    table.insert(lines, line)
                    line = { items = {}, main = 0, cross = 0 }
                end
                if #line.items > 0 then line.main += gap end
                table.insert(line.items, { node = c, size = s, at = line.main })
                line.main += main
                line.cross = math.max(line.cross, cross)
            end
            if #line.items > 0 then table.insert(lines, line) end
            local totalMain, totalCross = 0, 0
            for i, l in ipairs(lines) do
                totalMain = math.max(totalMain, l.main)
                totalCross += l.cross + (i > 1 and gap or 0)
            end
            local content = horizontal and Vector2.new(totalMain, totalCross) or Vector2.new(totalCross, totalMain)
            local placements = {}
            local hA, vA = p.HorizontalAlignment, p.VerticalAlignment
            local crossAt = 0
            for _, l in ipairs(lines) do
                for _, item in ipairs(l.items) do
                    local s = item.size
                    local pos
                    if horizontal then
                        pos = Vector2.new(item.at + U.align(hA, inner.X - l.main),
                            U.align(vA, inner.Y - content.Y) + crossAt + U.align(vA, l.cross - s.Y))
                    else
                        pos = Vector2.new(U.align(hA, inner.X - content.X) + crossAt + U.align(hA, l.cross - s.X),
                            item.at + U.align(vA, inner.Y - l.main))
                    end
                    placements[item.node] = { pos = pos, size = s }
                end
                crossAt += l.cross + gap
            end
            return placements, content
        end,
    })

    UI.RegisterClass("UIGridLayout", {
        Base = "UILayout",
        Defaults = function(p)
            p.CellSize = UDim2.fromOffset(100, 40); p.CellPadding = UDim2.fromOffset(8, 8)
            p.FillDirection = "Horizontal"; p.FillDirectionMaxCells = 0
        end,
        Arrange = function(layout, n, children, inner, scale)
            local p = layout._p
            local horizontal = U.enumName(p.FillDirection) == "Horizontal"
            ctx.sortForLayout(layout, children)
            local cell = U.vec(p.CellSize, inner, scale)
            cell = Vector2.new(math.max(1, cell.X), math.max(1, cell.Y))
            local gap = U.vec(p.CellPadding, inner, scale)
            local count = p.FillDirectionMaxCells
            if count <= 0 then
                count = math.floor(((horizontal and inner.X or inner.Y) + (horizontal and gap.X or gap.Y))
                    / math.max(1, horizontal and cell.X + gap.X or cell.Y + gap.Y))
            end
            count = math.max(1, math.floor(count))
            local rows = math.ceil(#children / count)
            local used = math.min(count, #children)
            local content = ZERO
            if #children > 0 then
                content = horizontal and Vector2.new(used * (cell.X + gap.X) - gap.X, rows * (cell.Y + gap.Y) - gap.Y)
                    or Vector2.new(rows * (cell.X + gap.X) - gap.X, used * (cell.Y + gap.Y) - gap.Y)
            end
            local offset = Vector2.new(U.align(p.HorizontalAlignment, inner.X - content.X), U.align(p.VerticalAlignment, inner.Y - content.Y))
            local placements = {}
            for i, c in ipairs(children) do
                local a, b = (i - 1) % count, math.floor((i - 1) / count)
                ctx.nodeSize(c, inner, scale)
                placements[c] = { pos = (horizontal and Vector2.new(a * (cell.X + gap.X), b * (cell.Y + gap.Y))
                    or Vector2.new(b * (cell.X + gap.X), a * (cell.Y + gap.Y))) + offset, size = cell }
            end
            return placements, content
        end,
    })
end
