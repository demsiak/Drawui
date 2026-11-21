-- Input/Input: hit testing, hover/press/click events, TextBox focus and editing, dragging,
-- scrolling, and the UserInputService / RenderStepped connections.
return function(UI, ctx)
    local U = ctx.U
    local Methods = ctx.Methods
    local clamp = U.clamp
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local fire = ctx.fire
    local drag, scrollDrag, repeatKey
    local lastBlink = -1
    local running = false
    ctx.mouse = U.ZERO

    -- Topmost hit region under `point`; rounded corners (UICorner) are respected.
    local function inside(h, point)
        if h.node._dead or not ctx.contains(h.rect, point) then return false end
        local r = h.radius or 0
        if r < 1 then return true end
        local p, s = h.pos, h.size
        r = math.min(r, s.X / 2, s.Y / 2)
        local dx = point.X - clamp(point.X, p.X + r, p.X + s.X - r)
        local dy = point.Y - clamp(point.Y, p.Y + r, p.Y + s.Y - r)
        return dx * dx + dy * dy <= r * r
    end
    local function hitTest(point)
        local hits = ctx.hits
        for i = #hits, 1, -1 do
            if inside(hits[i], point) then return hits[i] end
        end
    end
    ctx.hitTest = hitTest
    -- Interactive objects under a point, topmost first.
    function UI.GetGuiObjectsAtPosition(x, y)
        local out, point = {}, Vector2.new(x, y)
        for i = #ctx.hits, 1, -1 do
            local h = ctx.hits[i]
            if inside(h, point) and not table.find(out, h.node) then table.insert(out, h.node) end
        end
        return out
    end

    local function bubble(n, event, ...)
        while n do fire(n, event, ...); n = n._p.Parent end
    end

    -- Focus -----------------------------------------------------------------------------------------
    local function releaseFocus(enter, input)
        local old = ctx.focused
        ctx.focused = nil; repeatKey = nil
        if old and not old._dead then ctx.changed(old, "CursorPosition", -1); fire(old, "FocusLost", enter == true, input) end
        ctx.dirty = true
    end
    ctx.releaseFocus = releaseFocus
    function Methods:CaptureFocus()
        assert(self._p.ClassName == "TextBox", "CaptureFocus is only available on TextBox")
        if ctx.focused == self or not self._p.TextEditable then return end
        releaseFocus(false)
        ctx.focused = self
        if self._p.ClearTextOnFocus then self.Text = "" end
        self.CursorPosition = #self._p.Text + 1
        fire(self, "Focused")
        ctx.dirty = true
    end
    function Methods:ReleaseFocus(enter) if ctx.focused == self then releaseFocus(enter) end end
    function Methods:IsFocused() return ctx.focused == self end
    function UI.GetFocusedTextBox() return ctx.focused end

    -- Text editing ----------------------------------------------------------------------------------
    local function before(text, cursor) return utf8.offset(text, -1, cursor) or 1 end
    local function after(text, cursor) return utf8.offset(text, 2, cursor) or (#text + 1) end
    local shifted = { One = "!", Two = "@", Three = "#", Four = "$", Five = "%", Six = "^", Seven = "&", Eight = "*", Nine = "(", Zero = ")",
        Minus = "_", Equals = "+", LeftBracket = "{", RightBracket = "}", BackSlash = "|", Semicolon = ":", Quote = '"', Comma = "<", Period = ">", Slash = "?", Backquote = "~" }
    local plain = { One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
        Space = " ", Minus = "-", Equals = "=", LeftBracket = "[", RightBracket = "]", BackSlash = "\\", Semicolon = ";", Quote = "'", Comma = ",", Period = ".", Slash = "/", Backquote = "`" }
    local function editKey(input)
        local n = ctx.focused
        if not n or n._dead or not n._p.TextEditable then return end
        local key = input.KeyCode.Name
        local text = n._p.Text
        local cursor = clamp(n._p.CursorPosition, 1, #text + 1)
        -- Programmatic CursorPosition follows Roblox's UTF-8 byte indexing convention.
        while cursor > 1 and cursor <= #text and string.byte(text, cursor) >= 128 and string.byte(text, cursor) < 192 do cursor -= 1 end
        local ctrl = UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)
        local shift = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
        if key == "Escape" then releaseFocus(false, input); return
        elseif key == "Return" or key == "KeypadEnter" then
            if not n._p.MultiLine or ctrl then releaseFocus(true, input); return end
        elseif key == "Left" then n.CursorPosition = before(text, cursor); return
        elseif key == "Right" then n.CursorPosition = after(text, cursor); return
        elseif key == "Home" then n.CursorPosition = 1; return
        elseif key == "End" then n.CursorPosition = #text + 1; return
        elseif key == "Backspace" then
            if cursor > 1 then
                local prev = before(text, cursor)
                n.Text = string.sub(text, 1, prev - 1) .. string.sub(text, cursor)
                n.CursorPosition = prev
            end
            return
        elseif key == "Delete" then
            if cursor <= #text then n.Text = string.sub(text, 1, cursor - 1) .. string.sub(text, after(text, cursor)) end
            return
        end
        local insert
        if ctrl then
            if key == "V" and type(getclipboard) == "function" then
                local ok, value = pcall(getclipboard)
                if ok and type(value) == "string" then insert = value end
            end
        elseif #key == 1 then insert = shift and key or string.lower(key)
        elseif key == "Return" or key == "KeypadEnter" then insert = "\n"
        else insert = (shift and shifted[key]) or plain[key] end
        if insert then
            if not utf8.len(insert) then return end
            if not n._p.MultiLine then insert = string.gsub(insert, "[\r\n]", "") end
            if (utf8.len(text) or 0) + (utf8.len(insert) or 0) <= n._p.MaxLength then
                n.Text = string.sub(text, 1, cursor - 1) .. insert .. string.sub(text, cursor)
                n.CursorPosition = cursor + #insert
            end
        end
    end

    function UI.MakeDraggable(target, handle)
        handle = handle or target
        handle.Active = true
        return handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                drag = { target = target, handle = handle, from = ctx.mouse, position = target._p.Position }
            end
        end)
    end

    -- Per-frame input work (called by the renderer before drawing).
    function ctx.inputStep()
        if repeatKey and os.clock() >= repeatKey.at then
            editKey(repeatKey.input)
            if repeatKey then repeatKey.at = os.clock() + 0.04 end
        end
        if ctx.focused then
            local blink = math.floor(os.clock() * 2)
            if blink ~= lastBlink then lastBlink = blink; ctx.dirty = true end
        end
        local mouse = ctx.mouse
        local h = hitTest(mouse)
        local newHover = h and h.node
        if newHover ~= ctx.hovered then
            fire(ctx.hovered, "MouseLeave", mouse.X, mouse.Y)
            ctx.hovered = newHover
            fire(newHover, "MouseEnter", mouse.X, mouse.Y)
            ctx.dirty = true
        end
    end

    table.insert(ctx.destroyHooks, function(n)
        if ctx.focused == n then releaseFocus(false) end
        if ctx.hovered == n then ctx.hovered = nil end
        if ctx.pressed == n then ctx.pressed = nil end
        if drag and (drag.target == n or drag.handle == n) then drag = nil end
        if scrollDrag and scrollDrag.node == n then scrollDrag = nil end
    end)
    table.insert(ctx.shutdownHooks, function()
        drag, scrollDrag, repeatKey = nil, nil, nil
        ctx.hovered, ctx.pressed = nil, nil
        running = false
    end)

    local function pointer(input)
        if input.UserInputType == Enum.UserInputType.Touch then return Vector2.new(input.Position.X, input.Position.Y) end
        return UIS:GetMouseLocation()
    end

    function ctx.start()
        if running then return end
        assert(Drawing and type(Drawing.new) == "function", "Drawui requires an executor with Drawing.new")
        running = true
        local function connect(event, fn) table.insert(ctx.connections, event:Connect(fn)) end
        connect(UIS.InputBegan, function(input)
            local kind = input.UserInputType
            if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton2 then
                ctx.mouse = pointer(input)
                ctx.update(0)
                local mouse = ctx.mouse
                local h = hitTest(mouse)
                local node = h and h.node
                if kind == Enum.UserInputType.MouseButton2 then
                    if node then bubble(node, "InputBegan", input, false) end
                    return
                end
                if ctx.focused and ctx.focused ~= node then releaseFocus(false, input) end
                ctx.pressed = node
                ctx.dirty = true
                if node then
                    if h.scrollbar then scrollDrag = { node = node, from = mouse.Y, canvas = node._p.CanvasPosition.Y, height = h.height } end
                    if node._p.ClassName == "TextBox" then node:CaptureFocus() end
                    bubble(node, "InputBegan", input, false)
                    fire(node, "MouseButton1Down", mouse.X, mouse.Y)
                end
            elseif kind == Enum.UserInputType.Keyboard and ctx.focused then
                editKey(input)
                if ctx.focused then repeatKey = { input = input, at = os.clock() + 0.45 } end
            end
        end)
        connect(UIS.InputChanged, function(input)
            local kind = input.UserInputType
            if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
                ctx.mouse = pointer(input)
                local mouse = ctx.mouse
                if drag and not drag.target._dead then
                    local p = drag.position
                    local parent = drag.target._p.Parent
                    local delta = (mouse - drag.from) / (parent and parent._scale or 1)
                    drag.target.Position = UDim2.new(p.X.Scale, p.X.Offset + delta.X, p.Y.Scale, p.Y.Offset + delta.Y)
                end
                if scrollDrag and not scrollDrag.node._dead then
                    local n = scrollDrag.node
                    local travel = math.max(1, n._p.AbsoluteSize.Y - scrollDrag.height)
                    n.CanvasPosition = Vector2.new(n._p.CanvasPosition.X, scrollDrag.canvas
                        + (mouse.Y - scrollDrag.from) / travel * (n._p.AbsoluteCanvasSize.Y - n._p.AbsoluteSize.Y))
                end
                local h = hitTest(mouse)
                if h then fire(h.node, "MouseMoved", mouse.X, mouse.Y); bubble(h.node, "InputChanged", input, false) end
            elseif kind == Enum.UserInputType.MouseWheel then
                local h = hitTest(UIS:GetMouseLocation())
                local n = h and h.node
                while n do
                    local p = n._p
                    if p.ClassName == "ScrollingFrame" and p.ScrollingEnabled then
                        local delta = input.Position.Z * 36 * n._scale
                        if U.enumName(p.ScrollingDirection) == "X" then n.CanvasPosition = Vector2.new(p.CanvasPosition.X - delta, p.CanvasPosition.Y)
                        else n.CanvasPosition = Vector2.new(p.CanvasPosition.X, p.CanvasPosition.Y - delta) end
                        break
                    end
                    n = p.Parent
                end
            end
        end)
        connect(UIS.InputEnded, function(input)
            local kind = input.UserInputType
            if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
                local old = ctx.pressed
                ctx.pressed = nil; drag = nil; scrollDrag = nil; ctx.dirty = true
                local mouse = ctx.mouse
                local h = hitTest(mouse)
                if old and not old._dead then
                    bubble(old, "InputEnded", input, false)
                    fire(old, "MouseButton1Up", mouse.X, mouse.Y)
                    if h and h.node == old then fire(old, "MouseButton1Click"); fire(old, "Activated", input, 1) end
                end
            elseif kind == Enum.UserInputType.MouseButton2 then
                local h = hitTest(ctx.mouse)
                if h then fire(h.node, "MouseButton2Click"); bubble(h.node, "InputEnded", input, false) end
            elseif repeatKey and repeatKey.input.KeyCode == input.KeyCode then
                repeatKey = nil
            end
        end)
        connect(UIS.WindowFocusReleased, function()
            ctx.pressed = nil; drag = nil; scrollDrag = nil; repeatKey = nil
            releaseFocus(false)
            ctx.dirty = true
        end)
        connect(RunService.RenderStepped, function(dt)
            local ok, err = pcall(ctx.update, dt)
            if not ok then
                -- Stop on a renderer failure instead of logging the same error every frame.
                warn("[Drawui] Renderer stopped: " .. tostring(err))
                UI.Destroy()
            end
        end)
        ctx.mouse = UIS:GetMouseLocation()
        ctx.dirty = true
    end
end
