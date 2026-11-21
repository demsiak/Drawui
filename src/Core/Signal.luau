-- Core/Signal: RBXScriptSignal-like events (Connect, Once, Wait, Fire, Destroy).
return function(UI, ctx)
    local function signal()
        local s = { _handlers = {} }
        function s:Connect(fn)
            assert(type(fn) == "function", "Connect expects a function")
            local c = { Connected = true }
            function c:Disconnect()
                if self.Connected then self.Connected = false; s._handlers[self] = nil end
            end
            self._handlers[c] = fn
            return c
        end
        function s:Once(fn)
            local c
            c = self:Connect(function(...) c:Disconnect(); fn(...) end)
            return c
        end
        function s:Wait()
            local thread = coroutine.running()
            self:Once(function(...) task.spawn(thread, ...) end)
            return coroutine.yield()
        end
        function s:Fire(...)
            local pending = {}
            for c, fn in pairs(self._handlers) do table.insert(pending, { c, fn }) end
            for _, h in ipairs(pending) do
                if h[1].Connected then task.spawn(h[2], ...) end
            end
        end
        function s:Destroy()
            for c in pairs(self._handlers) do c.Connected = false end
            table.clear(self._handlers)
        end
        return s
    end
    ctx.signal = signal
    UI.Signal = signal
end
