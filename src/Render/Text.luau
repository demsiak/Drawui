-- Render/Text: measurement (cached), wrapping, TextScaled fitting and text drawing.
return function(UI, ctx)
    local U = ctx.U
    local clamp = U.clamp
    local measureObject
    local measureCache, measureCount = {}, 0

    local function fontId(font)
        if type(font) == "number" then return font end
        local name = U.enumName(font)
        if name == "Code" or name == "RobotoMono" or name == "Monospace" then return 3 end
        if name == "Arial" or name == "ArialBold" or name == "System" then return 1 end
        if name == "Plex" then return 2 end
        return 0
    end
    ctx.fontId = fontId

    local function measure(text, size, font)
        size = math.max(1, math.floor(size + 0.5)); font = fontId(font)
        local key = font .. ":" .. size .. ":" .. text
        local cached = measureCache[key]
        if cached then return cached end
        if not measureObject then measureObject = Drawing.new("Text"); measureObject.Visible = false end
        measureObject.Font = font; measureObject.Size = size; measureObject.Text = text
        local bounds = measureObject.TextBounds
        if measureCount > 2048 then table.clear(measureCache); measureCount = 0 end
        measureCache[key] = bounds; measureCount += 1
        return bounds
    end
    ctx.measure = measure
    function UI.MeasureText(text, size, font) return measure(tostring(text), size or 16, font or 0) end
    table.insert(ctx.shutdownHooks, function()
        if measureObject then measureObject:Destroy(); measureObject = nil end
    end)

    local function chars(text)
        local out = {}
        for _, cp in utf8.codes(text) do table.insert(out, utf8.char(cp)) end
        return out
    end
    ctx.chars = chars

    local function textLines(text, width, size, font, wrapped)
        local lines = {}
        for paragraph in string.gmatch(text .. "\n", "(.-)\n") do
            if not wrapped or paragraph == "" then table.insert(lines, paragraph)
            else
                local line = ""
                for word in string.gmatch(paragraph, "%S+%s*") do
                    if line ~= "" and measure(line .. word, size, font).X > width then
                        table.insert(lines, (string.gsub(line, "%s+$", ""))); line = ""
                    end
                    if measure(word, size, font).X > width then
                        for _, c in ipairs(chars(word)) do
                            if line ~= "" and measure(line .. c, size, font).X > width then table.insert(lines, line); line = "" end
                            line ..= c
                        end
                    else line ..= word end
                end
                table.insert(lines, (string.gsub(line, "%s+$", "")))
            end
        end
        return lines
    end

    local function displayText(n)
        local p = n._p
        if p.ClassName == "TextBox" and p.Text == "" and ctx.focused ~= n then return p.PlaceholderText, true end
        return p.Text, false
    end

    function ctx.textMetrics(n, width, height)
        local p = n._p
        local text = displayText(n)
        local size = math.max(1, math.floor(p.TextSize * n._scale + 0.5))
        local lines = textLines(text, width, size, p.Font, p.TextWrapped)
        if p.TextScaled then
            local minSize, maxSize = 1, math.huge
            local limits, limitsFn = ctx.modifier(n, "TextSizeLimits")
            if limits then minSize, maxSize = limitsFn(limits, n) end
            local low = math.max(1, math.floor(minSize))
            local high = math.max(low, math.floor(math.min(height, maxSize)))
            while low < high do
                local mid = math.ceil((low + high) / 2)
                local test = textLines(text, width, mid, p.Font, p.TextWrapped)
                local w = 0
                for _, line in ipairs(test) do w = math.max(w, measure(line, mid, p.Font).X) end
                if w <= width and #test * mid * p.LineHeight <= height then low = mid else high = mid - 1 end
            end
            size = low
            lines = textLines(text, width, size, p.Font, p.TextWrapped)
        end
        local lineHeight = math.max(size, measure("Ag", size, p.Font).Y) * p.LineHeight
        local maxWidth = 0
        for _, line in ipairs(lines) do maxWidth = math.max(maxWidth, measure(line, size, p.Font).X) end
        return lines, size, lineHeight, Vector2.new(maxWidth, #lines * lineHeight)
    end

    -- Layout hook for text classes: publishes TextBounds and grows AutomaticSize content.
    function ctx.textPreChildren(n, info)
        local _, _, _, bounds = ctx.textMetrics(n, info.inner.X, info.inner.Y)
        ctx.changed(n, "TextBounds", bounds)
        info.content = Vector2.new(math.max(info.content.X, bounds.X), math.max(info.content.Y, bounds.Y))
    end

    -- Draw hook for text classes. Text is clipped at character / line granularity.
    function ctx.drawText(n, style)
        local p = n._p
        local pos, s = style.pos, style.size
        local tl, br = ctx.padding(n, s, n._scale)
        local inner = s - tl - br
        local textClip = ctx.intersect(style.clip, ctx.rect(pos + tl, inner))
        if not ctx.nonempty(textClip) then return end
        local lines, size, lh, bounds = ctx.textMetrics(n, inner.X, inner.Y)
        local y = pos.Y + tl.Y + U.align(p.TextYAlignment, inner.Y - bounds.Y)
        local _, placeholder = displayText(n)
        local color = placeholder and p.PlaceholderColor3 or p.TextColor3
        local opacity = style.opacity * (1 - p.TextTransparency)
        color = U.multiply(color, style.tint)
        if style.gradient and style.gradient.ApplyToText then
            local c, a = ctx.gradientAt(style.gradient, 0.5)
            color, opacity = U.multiply(color, c), opacity * a
        end
        local stroke = style.textStroke
        local outline = stroke ~= nil or p.TextStrokeTransparency < 1
        local outlineColor = stroke and stroke.Color or p.TextStrokeColor3
        local glyphHeight = math.max(size, measure("Ag", size, p.Font).Y)
        for i, text in ipairs(lines) do
            local width = measure(text, size, p.Font).X
            local x = pos.X + tl.X + U.align(p.TextXAlignment, inner.X - width)
            local yy = y + (i - 1) * lh
            if yy >= textClip.y and yy + glyphHeight <= textClip.b then
                local originalX = x
                if x < textClip.x or x + width > textClip.r then
                    local result, offset = "", 0
                    for _, c in ipairs(chars(text)) do
                        local nextOffset = offset + measure(c, size, p.Font).X
                        if originalX + offset >= textClip.x and originalX + nextOffset <= textClip.r then
                            if result == "" then x = originalX + offset end
                            result ..= c
                        end
                        offset = nextOffset
                    end
                    text = result
                end
                local at = Vector2.new(x, yy)
                local t = ctx.transform
                if t and text ~= "" then
                    -- Drawing Text can't rotate: keep the glyphs upright, centred on the rotated line centre.
                    local half = Vector2.new(measure(text, size, p.Font).X / 2, glyphHeight / 2)
                    local center = ctx.applyTransform(t, at + half)
                    at = center - half
                    if not ctx.contains(ctx.screenClip, center) then text = "" end
                end
                local shadow = style.textShadow
                if shadow and text ~= "" and opacity * shadow.Opacity > 0 then
                    local sp = at + shadow.Offset
                    ctx.primitive(n, "Text", { Position = Vector2.new(math.floor(sp.X), math.floor(sp.Y)), Text = text,
                        Font = fontId(p.Font), Size = size, Color = shadow.Color, Center = false,
                        Transparency = clamp(opacity * shadow.Opacity, 0, 1), Outline = false, OutlineColor = shadow.Color })
                end
                if text ~= "" and opacity > 0 then
                    ctx.primitive(n, "Text", { Position = Vector2.new(math.floor(at.X), math.floor(at.Y)), Text = text,
                        Font = fontId(p.Font), Size = size, Color = color, Center = false,
                        Transparency = clamp(opacity, 0, 1), Outline = outline, OutlineColor = outlineColor })
                end
            end
        end
        if ctx.focused == n and math.floor(os.clock() * 2) % 2 == 0 and #lines == 1 then
            local prefix = string.sub(p.Text, 1, math.max(0, p.CursorPosition - 1))
            local x = pos.X + tl.X + U.align(p.TextXAlignment, inner.X - bounds.X) + measure(prefix, size, p.Font).X
            ctx.line(n, Vector2.new(x, y), Vector2.new(x, y + size), color, style.opacity, math.max(1, n._scale), textClip)
        end
    end
end
