-- Render/Renderer: per-frame update, draw traversal and lifecycle API (Refresh, Destroy, GetStats).
-- Draw pipeline for each GuiObject:
--   style = class Style -> modifier Style (UICorner radius, UIGradient, UIStroke text outline)
--   modifier Underlay (UIShadow) -> background -> border -> modifier Overlay (UIStroke)
--   class Draw (text, image) -> hit region -> children -> class DrawAfter (scrollbar)
return function(UI, ctx)
    local U = ctx.U
    local WHITE = U.WHITE
    local lastViewport = U.ZERO

    local function drawNode(n, parentClip, opacity, tint)
        local p = n._p
        if not p.Visible then return end
        n._rendered = true
        table.clear(n._counts)
        local def = n._class
        local pos, size = p.AbsolutePosition, p.AbsoluteSize
        local area = ctx.rect(pos, size)
        local visible = ctx.intersect(area, parentClip)
        local style = { pos = pos, size = size, area = area, visible = visible, clip = parentClip,
            opacity = opacity, tint = tint, radius = 0, background = p.BackgroundColor3 }
        if def.Style then def.Style(n, style, ctx) end
        ctx.eachModifier(n, "Style", function(m, fn) fn(m, n, style, ctx) end)

        ctx.eachModifier(n, "Underlay", function(m, fn) fn(m, n, style, ctx) end)
        local bgOpacity = style.opacity * (1 - p.BackgroundTransparency)
        if bgOpacity > 0 and ctx.nonempty(visible) then
            ctx.fillShape(n, pos, size, style.radius, U.multiply(style.background, style.tint), bgOpacity, parentClip, style.gradient)
        end
        if p.BorderSizePixel > 0 then
            ctx.ring(n, pos, size, style.radius, 0, p.BorderSizePixel * n._scale,
                U.multiply(p.BorderColor3, style.tint), style.opacity, parentClip, false)
        end
        ctx.eachModifier(n, "Overlay", function(m, fn) fn(m, n, style, ctx) end)
        if ctx.nonempty(visible) then
            if def.Draw then def.Draw(n, style, ctx) end
            if def.Hittable and def.Hittable(n) and p.Interactable and style.opacity > 0 then
                table.insert(ctx.hits, { node = n, rect = visible, pos = pos, size = size, radius = style.radius })
            end
        end
        local clip = p.ClipsDescendants and visible or parentClip
        if ctx.nonempty(clip) then
            for _, c in ipairs(ctx.drawOrder(n)) do drawNode(c, clip, style.opacity, style.tint) end
        end
        if def.DrawAfter then def.DrawAfter(n, style, ctx) end
    end
    ctx.drawNode = drawNode

    function ctx.update(dt)
        ctx.stepTweens(dt or 0)
        ctx.inputStep()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        if viewport ~= lastViewport then lastViewport = viewport; ctx.dirty = true end
        if not ctx.dirty then return end
        local renderedRevision = ctx.revision
        ctx.dirty = false
        table.clear(ctx.hits)
        ctx.z = 0
        for n in pairs(ctx.objects) do
            n._rendered = false
            for _, e in pairs(n._draws) do e.used = false end
        end
        local roots = ctx.roots
        table.sort(roots, function(a, b)
            if a._p.DisplayOrder == b._p.DisplayOrder then return a._serial < b._serial end
            return a._p.DisplayOrder < b._p.DisplayOrder
        end)
        for _, root in ipairs(roots) do
            if root._p.Enabled and root._p.Visible then
                local inset = U.ZERO
                if not root._p.IgnoreGuiInset then inset = game:GetService("GuiService"):GetGuiInset() end
                -- Bounded passes resolve ordinary nested AutomaticSize layouts.
                for _ = 1, 4 do ctx.layoutNode(root, inset, viewport - inset, 1) end
                drawNode(root, ctx.rect(inset, viewport - inset), 1, WHITE)
            end
        end
        for n in pairs(ctx.objects) do
            for _, e in pairs(n._draws) do
                if not e.used and e.props.Visible ~= false then e.object.Visible = false; e.props.Visible = false end
            end
        end
        -- Layout may have set read-only metrics; those changes are already rendered.
        ctx.dirty = ctx.revision ~= renderedRevision
        local focused = ctx.focused
        if focused and (not focused._rendered or focused._dead) then ctx.releaseFocus(false) end
    end

    function UI.Refresh() ctx.dirty = true; ctx.update(0) end
    function UI.Destroy()
        for _, root in ipairs(table.clone(ctx.roots)) do root:Destroy() end
        for n in pairs(ctx.objects) do if not n._dead then n:Destroy() end end
    end
    function UI.GetStats()
        local count, draws = 0, 0
        for n in pairs(ctx.objects) do
            count += 1
            for _ in pairs(n._draws) do draws += 1 end
        end
        return { Objects = count, Drawings = draws, Roots = #ctx.roots, Connections = #ctx.connections, Tweens = #ctx.tweens }
    end
end
