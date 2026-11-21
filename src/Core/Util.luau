-- Core/Util: pure helpers shared by every module (math, UDim resolution, enums, colors, sequences).
return function(UI, ctx)
    local U = {}
    ctx.U = U

    UI.Version = "2.0.0"
    UI.Fonts = { UI = 0, System = 1, Plex = 2, Monospace = 3 }

    U.ZERO = Vector2.new(0, 0)
    U.WHITE = Color3.new(1, 1, 1)
    U.BLACK = Color3.new(0, 0, 0)

    function U.clamp(v, a, b) return math.max(a, math.min(b, v)) end
    function U.enumName(v) return typeof(v) == "EnumItem" and v.Name or tostring(v) end
    function U.isAuto(value, axis) local s = U.enumName(value); return s == "XY" or s == axis end
    function U.udim(u, total, scale) return u.Scale * total + u.Offset * scale end
    function U.vec(u, total, scale)
        return Vector2.new(U.udim(u.X, total.X, scale), U.udim(u.Y, total.Y, scale))
    end
    function U.toUDim(v) if type(v) == "number" then return UDim.new(0, v) end; return v end
    function U.align(name, free)
        name = U.enumName(name)
        if name == "Center" then return free / 2 end
        if name == "Right" or name == "Bottom" then return free end
        return 0
    end

    function U.multiply(a, b) return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B) end
    function U.mix(a, b, t)
        if type(a) == "number" then return a + (b - a) * t end
        return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
    end

    -- Accepts ColorSequence / NumberSequence, a single Color3 / number, a list of values
    -- ({c1, c2, c3} spread evenly) or a list of {time, value} pairs. Returns {Time, Value} keypoints.
    function U.keypoints(seq)
        local kind = typeof(seq)
        if kind == "ColorSequence" or kind == "NumberSequence" then return seq.Keypoints end
        if kind == "Color3" or kind == "number" then
            return { { Time = 0, Value = seq }, { Time = 1, Value = seq } }
        end
        assert(type(seq) == "table" and #seq > 0, "Expected a ColorSequence, NumberSequence, Color3, number or list")
        local out = {}
        for i, k in ipairs(seq) do
            if typeof(k) == "Color3" or type(k) == "number" then
                table.insert(out, { Time = #seq > 1 and (i - 1) / (#seq - 1) or 0, Value = k })
            elseif type(k) == "table" and k[1] ~= nil then
                table.insert(out, { Time = k[1], Value = k[2] })
            else
                table.insert(out, k)
            end
        end
        if #out == 1 then table.insert(out, { Time = 1, Value = out[1].Value }) end
        return out
    end
    function U.sample(kp, t)
        t = U.clamp(t, 0, 1)
        if t <= kp[1].Time then return kp[1].Value end
        for i = 2, #kp do
            local a, b = kp[i - 1], kp[i]
            if t <= b.Time then return U.mix(a.Value, b.Value, (t - a.Time) / math.max(1e-6, b.Time - a.Time)) end
        end
        return kp[#kp].Value
    end
    function U.constant(kp)
        for i = 2, #kp do if kp[i].Value ~= kp[1].Value then return false end end
        return true
    end
end
