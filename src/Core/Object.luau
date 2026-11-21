-- Core/Object: property storage, events, parenting, UI.new and the shared Instance methods.
return function(UI, ctx)
    local U, signal, classes = ctx.U, ctx.signal, ctx.classes
    local Methods, Meta = {}, {}
    ctx.Methods, ctx.Meta = Methods, Meta
    ctx.roots, ctx.objects, ctx.connections, ctx.hits = {}, {}, {}, {}
    ctx.destroyHooks, ctx.shutdownHooks = {}, {}
    ctx.serial, ctx.revision, ctx.dirty = 0, 0, true

    local eventNames = {}
    for _, key in ipairs({ "Changed", "ChildAdded", "ChildRemoved", "AncestryChanged", "Destroying",
        "MouseEnter", "MouseLeave", "MouseMoved", "InputBegan", "InputChanged", "InputEnded",
        "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseButton2Click", "Activated",
        "Focused", "FocusLost", "AttributeChanged" }) do eventNames[key] = true end
    ctx.eventNames = eventNames

    local function changed(n, key, value)
        local p = n._p
        if p[key] == value then return end
        p[key] = value
        ctx.dirty = true
        if n._events.Changed then n._events.Changed:Fire(key) end
        if n._changed[key] then n._changed[key]:Fire() end
    end
    ctx.changed = changed
    local function fire(n, event, ...)
        if n and not n._dead and n._events[event] then n._events[event]:Fire(...) end
    end
    ctx.fire = fire
    function ctx.isLive(v) return getmetatable(v) == Meta and not v._dead end

    function Meta.__index(n, key)
        local method = Methods[key]
        if method then return method end
        if eventNames[key] then
            if not n._events[key] then n._events[key] = signal() end
            return n._events[key]
        end
        local value = n._p[key]
        if value ~= nil then return value end
        for _, c in ipairs(n._children) do if c._p.Name == key then return c end end
        return nil
    end
    function Meta.__newindex(n, key, value)
        assert(type(key) == "string", "Property names must be strings")
        if string.sub(key, 1, 1) == "_" then rawset(n, key, value); return end
        assert(not n._dead, "Cannot change a destroyed UI object")
        if key == "Parent" then ctx.setParent(n, value); return end
        assert(not ctx.readonly[key], key .. " is read-only")
        assert(n._p[key] ~= nil, "Unsupported property: " .. n._p.ClassName .. "." .. key)
        local coerce = n._class.Coerce
        if coerce and coerce[key] then value = coerce[key](value) end
        ctx.revision += 1
        changed(n, key, value)
    end
    function Meta.__tostring(n) return n._p.Name end

    function ctx.setParent(n, parent)
        assert(parent == nil or ctx.isLive(parent), "Parent must be a live Drawui object or nil")
        assert(not parent or parent._class.Gui, parent and (parent._p.ClassName .. " cannot contain children") or "")
        assert(not n._class.Root or parent == nil, n._p.ClassName .. " must be a root")
        local p = parent
        while p do assert(p ~= n, "Parent would create a cycle"); p = p._p.Parent end
        local old = n._p.Parent
        if old == parent then return end
        if old then
            table.remove(old._children, table.find(old._children, n))
            fire(old, "ChildRemoved", n)
        end
        n._p.Parent = parent
        if parent then table.insert(parent._children, n); fire(parent, "ChildAdded", n) end
        ctx.revision += 1; ctx.dirty = true
        fire(n, "AncestryChanged", n, parent)
        fire(n, "Changed", "Parent")
        if n._changed.Parent then n._changed.Parent:Fire() end
    end

    function UI.new(class, props, children)
        local def = classes[class]
        assert(def and not def.Abstract, "Unsupported UI class: " .. tostring(class))
        ctx.serial += 1
        local n = setmetatable({ _p = ctx.defaults(def), _class = def, _children = {}, _events = {}, _changed = {},
            _draws = {}, _counts = {}, _serial = ctx.serial, _dead = false, _scale = 1, _ownScale = 1,
            _content = U.ZERO, _rendered = false, _attributes = {} }, Meta)
        ctx.objects[n] = true
        local ok, err = pcall(function()
            for key, value in pairs(props or {}) do if key ~= "Parent" then n[key] = value end end
            for _, c in ipairs(children or {}) do c.Parent = n end
            if props and props.Parent then n.Parent = props.Parent end
        end)
        if not ok then n:Destroy(); error(err, 2) end
        if def.Root then table.insert(ctx.roots, n); ctx.start() end
        ctx.dirty = true
        return n
    end
    UI.Create = UI.new

    function Methods:GetChildren() return table.clone(self._children) end
    function Methods:GetDescendants()
        local result = {}
        local function visit(n) for _, c in ipairs(n._children) do table.insert(result, c); visit(c) end end
        visit(self)
        return result
    end
    function Methods:FindFirstChild(name, recursive)
        for _, c in ipairs(self._children) do if c._p.Name == name then return c end end
        if recursive then
            for _, c in ipairs(self._children) do
                local found = c:FindFirstChild(name, true)
                if found then return found end
            end
        end
    end
    function Methods:FindFirstChildOfClass(class)
        for _, c in ipairs(self._children) do if c._p.ClassName == class then return c end end
    end
    function Methods:FindFirstChildWhichIsA(class)
        for _, c in ipairs(self._children) do if c._class.Is[class] then return c end end
    end
    function Methods:FindFirstAncestor(name)
        local p = self._p.Parent
        while p do if p._p.Name == name then return p end; p = p._p.Parent end
    end
    function Methods:FindFirstAncestorOfClass(class)
        local p = self._p.Parent
        while p do if p._p.ClassName == class then return p end; p = p._p.Parent end
    end
    function Methods:IsA(class) return self._class.Is[class] == true end
    function Methods:IsDescendantOf(parent)
        local p = self._p.Parent
        while p do if p == parent then return true end; p = p._p.Parent end
        return false
    end
    function Methods:GetPropertyChangedSignal(key)
        if not self._changed[key] then self._changed[key] = signal() end
        return self._changed[key]
    end
    function Methods:SetAttribute(key, value)
        if self._attributes[key] == value then return end
        self._attributes[key] = value
        fire(self, "AttributeChanged", key)
    end
    function Methods:GetAttribute(key) return self._attributes[key] end
    function Methods:GetAttributes() return table.clone(self._attributes) end
    function Methods:Clone()
        assert(not self._dead, "Cannot clone a destroyed object")
        local props = {}
        for key, value in pairs(self._p) do
            if not ctx.readonly[key] and key ~= "Parent" then props[key] = value end
        end
        local result = UI.new(self._p.ClassName, props)
        for _, c in ipairs(self._children) do c:Clone().Parent = result end
        result._attributes = table.clone(self._attributes)
        return result
    end
    function Methods:Destroy()
        if self._dead then return end
        fire(self, "Destroying")
        for _, hook in ipairs(ctx.destroyHooks) do hook(self) end
        for _, c in ipairs(table.clone(self._children)) do c:Destroy() end
        ctx.setParent(self, nil)
        for _, entry in pairs(self._draws) do entry.object:Destroy() end
        table.clear(self._draws)
        for _, s in pairs(self._events) do s:Destroy() end
        for _, s in pairs(self._changed) do s:Destroy() end
        ctx.objects[self] = nil
        local index = table.find(ctx.roots, self)
        if index then table.remove(ctx.roots, index) end
        self._dead = true
        ctx.dirty = true
        if #ctx.roots == 0 then ctx.shutdown() end
    end
    Methods.Remove = Methods.Destroy
    function Methods:ClearAllChildren() for _, c in ipairs(table.clone(self._children)) do c:Destroy() end end

    -- Called when the last root is destroyed: release every connection and cached drawing.
    function ctx.shutdown()
        for _, c in ipairs(ctx.connections) do c:Disconnect() end
        table.clear(ctx.connections)
        table.clear(ctx.hits)
        for _, hook in ipairs(ctx.shutdownHooks) do hook() end
    end
end
