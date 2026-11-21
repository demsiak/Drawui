-- Headless Roblox/Drawing test doubles. This file is NOT included in the demo.
local function typed(kind, values, meta)
    values._type = kind; return setmetatable(values, meta)
end
local nativeTypeof = typeof
local function typeof(v) return type(v) == "table" and rawget(v, "_type") or nativeTypeof(v) end
local Vector2, UDim, UDim2, Color3, TweenInfo = {}, {}, {}, {}, {}
local vm = {}
vm.__index = vm
function Vector2.new(x, y) return typed("Vector2", {X = x or 0, Y = y or 0}, vm) end
function vm.__add(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
function vm.__sub(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
function vm.__mul(a, b) return Vector2.new(a.X * b, a.Y * b) end
function vm.__div(a, b) return Vector2.new(a.X / b, a.Y / b) end
function vm.__eq(a, b) return a.X == b.X and a.Y == b.Y end
function vm:Lerp(b, t) return self + (b - self) * t end
local um = {__eq = function(a,b) return a.Scale == b.Scale and a.Offset == b.Offset end}
function UDim.new(s, o) return typed("UDim", {Scale = s or 0, Offset = o or 0}, um) end
local u2m = {}
u2m.__index = u2m
function UDim2.new(xs, xo, ys, yo) return typed("UDim2", {X = UDim.new(xs,xo), Y = UDim.new(ys,yo)}, u2m) end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
function u2m.__eq(a,b) return a.X == b.X and a.Y == b.Y end
function u2m:Lerp(b,t) return UDim2.new(self.X.Scale + (b.X.Scale-self.X.Scale)*t, self.X.Offset + (b.X.Offset-self.X.Offset)*t,
    self.Y.Scale + (b.Y.Scale-self.Y.Scale)*t, self.Y.Offset + (b.Y.Offset-self.Y.Offset)*t) end
local cm = {}
cm.__index = cm
function Color3.new(r,g,b) return typed("Color3", {R=r or 0,G=g or 0,B=b or 0}, cm) end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
function cm.__eq(a,b) return a.R == b.R and a.G == b.G and a.B == b.B end
function cm:Lerp(b,t) return Color3.new(self.R+(b.R-self.R)*t,self.G+(b.G-self.G)*t,self.B+(b.B-self.B)*t) end
local Enum = setmetatable({}, {__index = function(t,k)
    local group = setmetatable({}, {__index = function(g,n)
        local item = typed("EnumItem", {Name=n, EnumType=k}); rawset(g,n,item); return item
    end}); rawset(t,k,group); return group
end})
function TweenInfo.new(time,style,direction,repeats,reverses,delay)
    return {Time=time or 1,EasingStyle=style or Enum.EasingStyle.Quad,EasingDirection=direction or Enum.EasingDirection.Out,
        RepeatCount=repeats or 0,Reverses=reverses or false,DelayTime=delay or 0}
end
local ColorSequence, ColorSequenceKeypoint, NumberSequence, NumberSequenceKeypoint = {}, {}, {}, {}
function ColorSequenceKeypoint.new(t, v) return typed("ColorSequenceKeypoint", {Time=t, Value=v}, {}) end
function NumberSequenceKeypoint.new(t, v) return typed("NumberSequenceKeypoint", {Time=t, Value=v, Envelope=0}, {}) end
function ColorSequence.new(a, b)
    local kp = typeof(a) == "Color3" and {ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a)} or a
    return typed("ColorSequence", {Keypoints=kp}, {})
end
function NumberSequence.new(a, b)
    local kp = type(a) == "number" and {NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a)} or a
    return typed("NumberSequence", {Keypoints=kp}, {})
end
local function mockSignal()
    local s = {listeners={}}
    function s:Connect(fn)
        local c = {Connected=true}
        function c:Disconnect() self.Connected = false; s.listeners[self] = nil end
        self.listeners[c]=fn; return c
    end
    function s:Fire(...)
        local list = {}; for c,fn in pairs(self.listeners) do table.insert(list,{c,fn}) end
        for _,h in ipairs(list) do if h[1].Connected then h[2](...) end end
    end
    return s
end
local task = {}
function task.spawn(fn,...)
    if type(fn)=="thread" then assert(coroutine.resume(fn,...)); return fn end
    local t=coroutine.create(fn); local ok,err=coroutine.resume(t,...); assert(ok,err); return t
end
local drawingCreated, drawingDestroyed, drawingWrites = 0, 0, 0
local allDraws = {}
local allowed = {
    Square={Position=true,Size=true,Filled=true,Thickness=true},
    Circle={Position=true,Radius=true,Filled=true,Thickness=true,NumSides=true},
    Line={From=true,To=true,Thickness=true},
    Text={Position=true,Text=true,Size=true,Font=true,Center=true,Outline=true,OutlineColor=true},
    Image={Position=true,Data=true,Size=true,Rounding=true},
    Triangle={PointA=true,PointB=true,PointC=true,Thickness=true,Filled=true},
    Quad={PointA=true,PointB=true,PointC=true,PointD=true,Thickness=true,Filled=true},
}
local Drawing = {Fonts={UI=0,System=1,Plex=2,Monospace=3}}
function Drawing.new(kind)
    assert(allowed[kind], "Unknown Drawing type " .. kind)
    drawingCreated += 1
    local data, dead = {Text="",Size=16}, false
    local obj = setmetatable({}, {
        __index=function(_,k)
            if k=="Destroy" or k=="Remove" then return function() assert(not dead,"Double destroy"); dead=true; drawingDestroyed += 1 end end
            assert(not dead, "Reading a destroyed Drawing")
            if k=="TextBounds" then return Vector2.new((utf8.len(data.Text) or 0)*data.Size*0.55,data.Size) end
            return data[k]
        end,
        __newindex=function(_,k,v)
            assert(not dead,"Writing a destroyed Drawing")
            assert(k=="Color" or k=="Transparency" or k=="Visible" or k=="ZIndex" or allowed[kind][k], "Invalid "..kind.." property: "..k)
            drawingWrites += 1; data[k]=v
        end,
    })
    table.insert(allDraws,{object=obj,data=data,kind=kind,isDead=function() return dead end})
    return obj
end
local uis = {InputBegan=mockSignal(),InputChanged=mockSignal(),InputEnded=mockSignal(),WindowFocusReleased=mockSignal(),mouse=Vector2.new(0,0),keys={}}
function uis:GetMouseLocation() return self.mouse end
function uis:IsKeyDown(key) return self.keys[key.Name] == true end
local run = {RenderStepped=mockSignal()}
local workspace = {CurrentCamera={ViewportSize=Vector2.new(1200,800)}}
local services = {
    UserInputService=uis, RunService=run,
    GuiService={GetGuiInset=function() return Vector2.new(0,36),Vector2.new(0,0) end},
    TweenService={GetValue=function(_,v) return v end},
}
local game = {GetService=function(_,key) assert(services[key],"Unknown service "..key); return services[key] end}
local _G = {}
local function getgenv() return _G end
local warnings = {}
local function warn(msg) table.insert(warnings,msg) end
local function mouseMove(x,y)
    uis.mouse=Vector2.new(x,y)
    uis.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position={X=x,Y=y,Z=0},KeyCode=Enum.KeyCode.Unknown})
    run.RenderStepped:Fire(0.016)
end
local function click(x,y)
    mouseMove(x,y)
    local input={UserInputType=Enum.UserInputType.MouseButton1,Position={X=x,Y=y,Z=0},KeyCode=Enum.KeyCode.Unknown}
    uis.InputBegan:Fire(input); uis.InputEnded:Fire(input); run.RenderStepped:Fire(0.016)
end
local function key(name)
    local input={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode[name],Position={X=0,Y=0,Z=0}}
    uis.InputBegan:Fire(input,false); uis.InputEnded:Fire(input); run.RenderStepped:Fire(0.016)
end
