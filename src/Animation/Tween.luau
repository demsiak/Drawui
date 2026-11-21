-- Animation/Tween: TweenService-style tweens for number, Color3, Vector2, UDim and UDim2 properties.
return function(UI, ctx)
    local U = ctx.U
    local TweenService = game:GetService("TweenService")
    local tweens = {}
    ctx.tweens = tweens
    local tweenable = { number = true, Color3 = true, Vector2 = true, UDim2 = true, UDim = true }

    function UI.Tween(n, info, goal)
        assert(ctx.isLive(n), "Tween target must be a live UI object")
        info = info or TweenInfo.new(0.25)
        assert(info.RepeatCount == 0 and not info.Reverses, "RepeatCount/Reverses are not implemented")
        local t = { Completed = ctx.signal(), PlaybackState = Enum.PlaybackState.Begin, _from = {}, _elapsed = 0 }
        for key, value in pairs(goal) do
            assert(n._p[key] ~= nil and not ctx.readonly[key] and key ~= "Parent", "Invalid tween property: " .. key)
            assert(typeof(n._p[key]) == typeof(value), "Tween property types must match: " .. key)
            assert(tweenable[typeof(value)], "Unsupported tween value: " .. typeof(value))
        end
        function t:Play()
            if table.find(tweens, self) then return end
            assert(not n._dead, "Tween target was destroyed")
            for _, other in ipairs(table.clone(tweens)) do
                if other._target == n then
                    for key in pairs(goal) do if other._goal[key] ~= nil then other:Cancel(); break end end
                end
            end
            self._from = {}
            for key in pairs(goal) do self._from[key] = n._p[key] end
            self._elapsed = 0
            self.PlaybackState = Enum.PlaybackState.Playing
            self._target, self._goal, self._info = n, goal, info
            table.insert(tweens, self)
            ctx.start()
        end
        function t:Cancel()
            local i = table.find(tweens, self)
            if i then table.remove(tweens, i) end
            self.PlaybackState = Enum.PlaybackState.Cancelled
            self.Completed:Fire(self.PlaybackState)
        end
        t:Play()
        return t
    end
    function ctx.Methods:Tween(info, goal) return UI.Tween(self, info, goal) end

    local function lerp(from, to, alpha)
        if type(to) == "number" then return from + (to - from) * alpha end
        local kind = typeof(to)
        if kind == "UDim" then return UDim.new(from.Scale + (to.Scale - from.Scale) * alpha, from.Offset + (to.Offset - from.Offset) * alpha) end
        if kind == "Color3" then return U.mix(from, to, alpha) end
        return from:Lerp(to, alpha)
    end

    function ctx.stepTweens(dt)
        for _, t in ipairs(table.clone(tweens)) do
            if t._target._dead then t:Cancel()
            else
                t._elapsed += dt
                local info = t._info
                local raw = U.clamp((t._elapsed - info.DelayTime) / math.max(0.00001, info.Time), 0, 1)
                local alpha = TweenService:GetValue(raw, info.EasingStyle, info.EasingDirection)
                for key, to in pairs(t._goal) do t._target[key] = lerp(t._from[key], to, alpha) end
                if raw >= 1 then
                    local index = table.find(tweens, t)
                    if index then table.remove(tweens, index) end
                    t.PlaybackState = Enum.PlaybackState.Completed
                    t.Completed:Fire(t.PlaybackState)
                end
            end
        end
    end
    table.insert(ctx.shutdownHooks, function()
        for _, t in ipairs(table.clone(tweens)) do t:Cancel() end
    end)
end
