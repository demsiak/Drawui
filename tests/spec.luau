local passed = 0
local function check(name, fn)
    fn(); passed += 1; print("PASS " .. name)
end
local function near(a,b) assert(math.abs(a-b)<0.001, tostring(a).." ~= "..tostring(b)) end
local root = UI.new("ScreenGui")
local frame = UI.new("Frame", {Parent=root,Size=UDim2.fromOffset(400,300),Position=UDim2.fromOffset(40,50)})
local child = UI.new("Frame", {Name="Child",Parent=frame,Size=UDim2.fromOffset(100,40),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5)})
check("UDim2 and anchor positioning", function()
    UI.Refresh(); near(child.AbsolutePosition.X,190); near(child.AbsolutePosition.Y,180)
end)
check("property signals, cycles, clone and read-only metrics", function()
    local calls=0; child:GetPropertyChangedSignal("Name"):Connect(function() calls+=1 end)
    child.Name="Renamed"; assert(calls==1)
    assert(not pcall(function() frame.Parent=child end))
    assert(not pcall(function() child.AbsoluteSize=Vector2.new(1,1) end))
    assert(not pcall(function() child.Typo=1 end))
    local copy=frame:Clone(); assert(copy.Parent==nil and #copy:GetChildren()==1 and copy:FindFirstChild("Renamed")); copy:Destroy()
end)
local list=UI.new("Frame",{Parent=root,Position=UDim2.fromOffset(500,20),Size=UDim2.fromOffset(200,200)})
UI.new("UIPadding",{Parent=list,PaddingLeft=UDim.new(0,10),PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,8)})
local ll=UI.new("UIListLayout",{Parent=list,Padding=UDim.new(0,6)})
local a=UI.new("Frame",{Parent=list,Size=UDim2.fromOffset(50,30),LayoutOrder=2})
local b=UI.new("Frame",{Parent=list,Size=UDim2.fromOffset(70,20),LayoutOrder=1})
check("list layout, ordering and padding",function()
    UI.Refresh(); near(b.AbsolutePosition.Y,32); near(a.AbsolutePosition.Y,58); near(a.AbsolutePosition.X,510)
    near(ll.AbsoluteContentSize.Y,56)
end)
check("AutomaticSize grows and shrinks",function()
    list.AutomaticSize="Y"; UI.Refresh(); near(list.AbsoluteSize.Y,76)
    a.Visible=false; UI.Refresh(); near(list.AbsoluteSize.Y,40)
    a.Visible=true; list.AutomaticSize="None"
end)
check("grid layout",function()
    local grid=UI.new("Frame",{Parent=root,Size=UDim2.fromOffset(150,100)})
    local gl=UI.new("UIGridLayout",{Parent=grid,CellSize=UDim2.fromOffset(60,20),CellPadding=UDim2.fromOffset(10,5)})
    local cells={}; for i=1,4 do cells[i]=UI.new("Frame",{Parent=grid,LayoutOrder=i}) end
    UI.Refresh(); near(cells[3].AbsolutePosition.Y,25); near(cells[2].AbsolutePosition.X,70); near(gl.AbsoluteContentSize.Y,45)
    grid:Destroy()
end)
check("UIScale includes descendants and padding",function()
    local s=UI.new("UIScale",{Parent=frame,Scale=0.5}); UI.Refresh()
    near(frame.AbsoluteSize.X,200); near(child.AbsoluteSize.X,50); near(child.AbsolutePosition.X,115)
    s:Destroy(); UI.Refresh()
end)
local clicks, lower = 0, 0
local button=UI.new("TextButton",{Parent=root,Text="Test",Position=UDim2.fromOffset(30,400),Size=UDim2.fromOffset(160,40),ZIndex=20})
button.MouseButton1Click:Connect(function() clicks+=1 end)
check("hit testing, clicking, visibility and Interactable",function()
    UI.Refresh(); click(70,420); assert(clicks==1)
    button.Interactable=false; UI.Refresh(); click(70,420); assert(clicks==1)
    button.Interactable=true; button.Visible=false; UI.Refresh(); click(70,420); assert(clicks==1)
    button.Visible=true; UI.Refresh()
    local top=UI.new("TextButton",{Parent=root,Position=button.Position,Size=button.Size,ZIndex=21})
    top.MouseButton1Click:Connect(function() lower+=1 end); UI.Refresh(); click(70,420); assert(lower==1 and clicks==1)
    top:Destroy(); UI.Refresh()
end)
check("drawing pool stays stable and idle frames do not redraw",function()
    mouseMove(1100,750); UI.Refresh(); run.RenderStepped:Fire(0.016)
    local count,writes=drawingCreated,drawingWrites
    for _=1,20 do run.RenderStepped:Fire(0.016) end
    assert(drawingCreated==count); assert(drawingWrites==writes)
    button.Text="A new string"; UI.Refresh(); assert(drawingCreated==count)
end)
local scroll=UI.new("ScrollingFrame",{Parent=root,Position=UDim2.fromOffset(800,100),Size=UDim2.fromOffset(180,100)})
UI.new("UIListLayout",{Parent=scroll,Padding=UDim.new(0,5)})
for _=1,8 do UI.new("TextButton",{Parent=scroll,Size=UDim2.new(1,0,0,30),Text="Row"}) end
check("automatic canvas, wheel and clamp",function()
    UI.Refresh(); near(scroll.AbsoluteCanvasSize.Y,275)
    mouseMove(840,150)
    uis.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseWheel,Position={Z=-2}}); UI.Refresh()
    near(scroll.CanvasPosition.Y,72)
    scroll.CanvasPosition=Vector2.new(0,9999); UI.Refresh(); near(scroll.CanvasPosition.Y,175)
end)
check("scrollbar thumb drag",function()
    scroll.CanvasPosition=Vector2.new(0,0); UI.Refresh(); mouseMove(975,105)
    local input={UserInputType=Enum.UserInputType.MouseButton1,Position={X=975,Y=105},KeyCode=Enum.KeyCode.Unknown}
    uis.InputBegan:Fire(input); mouseMove(975,155); uis.InputEnded:Fire(input); UI.Refresh()
    assert(scroll.CanvasPosition.Y>100)
end)
local box=UI.new("TextBox",{Parent=root,Position=UDim2.fromOffset(30,470),Size=UDim2.fromOffset(200,40),TextXAlignment="Left"})
UI.new("UICorner",{Parent=box}); UI.new("UIPadding",{Parent=box,PaddingLeft=UDim.new(0,8)})
check("TextBox focus, keyboard, UTF-8 editing and Enter",function()
    UI.Refresh(); click(50,490); assert(box:IsFocused())
    key("A"); key("B"); assert(box.Text=="ab")
    box.Text="aą"; box.CursorPosition=#box.Text+1; key("Backspace"); assert(box.Text=="a")
    box.Text="ąć"; box.CursorPosition=1; key("Delete"); assert(box.Text=="ć")
    key("End"); key("Left"); key("X"); assert(box.Text=="xć")
    local entered=false; box.FocusLost:Once(function(enter) entered=enter end)
    key("Return"); assert(entered and not box:IsFocused())
end)
check("tween completion, cancel and replacement",function()
    local t=UI.Tween(button,TweenInfo.new(1),{BackgroundTransparency=0.5})
    run.RenderStepped:Fire(0.5); near(button.BackgroundTransparency,0.25)
    run.RenderStepped:Fire(0.5); near(button.BackgroundTransparency,0.5); assert(t.PlaybackState==Enum.PlaybackState.Completed)
    local old=UI.Tween(button,TweenInfo.new(1),{BackgroundTransparency=1})
    UI.Tween(button,TweenInfo.new(1),{BackgroundTransparency=0}); assert(old.PlaybackState==Enum.PlaybackState.Cancelled)
    run.RenderStepped:Fire(1); near(button.BackgroundTransparency,0)
end)
check("dragging",function()
    UI.MakeDraggable(button); UI.Refresh(); mouseMove(70,420)
    local input={UserInputType=Enum.UserInputType.MouseButton1,Position={X=70,Y=420},KeyCode=Enum.KeyCode.Unknown}
    uis.InputBegan:Fire(input); mouseMove(110,450); uis.InputEnded:Fire(input); UI.Refresh()
    near(button.Position.X.Offset,70); near(button.Position.Y.Offset,430)
end)
local function visibleDraws(n, prefix)
    local out = {}
    for key, e in pairs(n._draws) do
        if e.props.Visible and (not prefix or string.sub(key, 1, #prefix) == prefix) then table.insert(out, e.props) end
    end
    return out
end
local function minX(n)
    local x = math.huge
    for _, props in ipairs(visibleDraws(n)) do
        for _, k in ipairs({"PointA","PointB","PointC","PointD","Position"}) do if props[k] then x = math.min(x, props[k].X) end end
    end
    return x
end
check("UICorner: corner quads, number shorthand, rounded hit area",function()
    local f=UI.new("TextButton",{Parent=root,Text="",Position=UDim2.fromOffset(600,600),Size=UDim2.fromOffset(100,60),ZIndex=30})
    UI.new("UICorner",{Parent=f,CornerRadius=20})
    assert(typeof(f.UICorner.CornerRadius)=="UDim" and f.UICorner.CornerRadius.Offset==20)
    UI.Refresh()
    -- Opaque: overlapping corner circles + cross of squares (seamless).
    assert(#visibleDraws(f,"Circle")==4 and #visibleDraws(f,"Quad")==0 and #visibleDraws(f,"Square")==2)
    -- Translucent: exact disjoint pieces (no doubled alpha).
    f.BackgroundTransparency=0.5; UI.Refresh()
    assert(#visibleDraws(f,"Circle")==0 and #visibleDraws(f,"Quad")>0)
    f.BackgroundTransparency=0; f.Position=UDim2.new(0,600.4,0,600.6); UI.Refresh()
    for _,props in ipairs(visibleDraws(f,"Square")) do assert(props.Position.X%1==0 and props.Position.Y%1==0) end
    f.Position=UDim2.fromOffset(600,600); UI.Refresh()
    assert(not table.find(UI.GetGuiObjectsAtPosition(601,601),f))
    assert(table.find(UI.GetGuiObjectsAtPosition(650,630),f))
    f:Destroy()
end)
check("UIStroke: outer/inner positions and contextual text outline",function()
    local f=UI.new("Frame",{Parent=root,Position=UDim2.fromOffset(600,600),Size=UDim2.fromOffset(100,60)})
    local s=UI.new("UIStroke",{Parent=f,Thickness=4}); UI.Refresh()
    near(minX(f),596)
    s.BorderStrokePosition="Inner"; UI.Refresh(); near(minX(f),600)
    local t=UI.new("TextLabel",{Parent=root,Text="Outlined",Position=UDim2.fromOffset(600,700),Size=UDim2.fromOffset(120,30)})
    UI.new("UIStroke",{Parent=t,Color=Color3.new(1,0,0)}); UI.Refresh()
    local found=false
    for _,props in ipairs(visibleDraws(t,"Text")) do found=props.Outline==true and props.OutlineColor==Color3.new(1,0,0) end
    assert(found and #visibleDraws(t,"Quad")==0)
    f:Destroy(); t:Destroy()
end)
check("UIGradient: colour bands, rotation and rounded clipping",function()
    local f=UI.new("Frame",{Parent=root,Position=UDim2.fromOffset(600,600),Size=UDim2.fromOffset(120,60),BackgroundColor3=Color3.new(1,1,1)})
    local g=UI.new("UIGradient",{Parent=f,Color=ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,1))}); UI.Refresh()
    local bands=visibleDraws(f,"Square")
    table.sort(bands,function(a,b) return a.Position.X<b.Position.X end)
    assert(#bands>=4 and bands[1].Color.R>0.9 and bands[#bands].Color.B>0.9)
    g.Rotation=45; UI.new("UICorner",{Parent=f}); UI.Refresh()
    assert(#visibleDraws(f,"Quad")+#visibleDraws(f,"Triangle")>0)
    g.Transparency=NumberSequence.new(0,1); UI.Refresh()
    f:Destroy()
end)
check("UIShadow (Roblox API): outer, inset, text mode, coercion",function()
    local f=UI.new("Frame",{Parent=root,Position=UDim2.fromOffset(600,600),Size=UDim2.fromOffset(100,60)})
    local s=UI.new("UIShadow",{Parent=f,BlurRadius=12,Offset=Vector2.new(0,8),Transparency=0.4})
    assert(typeof(s.BlurRadius)=="UDim" and typeof(s.Offset)=="UDim2" and s.Offset.Y.Offset==8 and s.Mode=="Shape")
    UI.Refresh()
    local maxY=0
    for _,props in ipairs(visibleDraws(f,"Square")) do maxY=math.max(maxY,props.Position.Y+props.Size.Y) end
    assert(maxY>660, maxY)
    -- Inset: shadow stays inside the frame.
    s.Inset=true; UI.Refresh()
    for _,props in ipairs(visibleDraws(f)) do
        for _,k in ipairs({"PointA","PointB","PointC","PointD"}) do
            if props[k] then assert(props[k].X>=600-0.01 and props[k].X<=700.01 and props[k].Y>=600-0.01 and props[k].Y<=660.01) end
        end
    end
    s:Destroy()
    -- Text mode: a second, offset Text drawing under the label.
    local t=UI.new("TextLabel",{Parent=root,Text="Shadow",Position=UDim2.fromOffset(600,700),Size=UDim2.fromOffset(120,30)})
    UI.new("UIShadow",{Parent=t,Mode="Text",Offset=Vector2.new(2,2),Color=Color3.new(1,0,0)}); UI.Refresh()
    local texts=visibleDraws(t,"Text"); assert(#texts==2, #texts)
    table.sort(texts,function(a,b) return a.ZIndex<b.ZIndex end)
    assert(texts[1].Color==Color3.new(1,0,0) and texts[1].Position.X==texts[2].Position.X+2)
    -- Builder: Shadow = true preset, legacy Blur key.
    local b=UI.New "Frame" {Parent=root,Shadow={Blur=10,Offset=Vector2.new(0,4)}}
    assert(b:FindFirstChildOfClass("UIShadow").BlurRadius.Offset==10)
    local c=UI.New "Frame" {Parent=root,Shadow=true}
    assert(c:FindFirstChildOfClass("UIShadow").BlurRadius.Offset==18)
    f:Destroy(); t:Destroy(); b:Destroy(); c:Destroy()
end)
check("Rotation: rotated geometry, upright text, hit testing, AbsoluteRotation",function()
    local f=UI.new("TextButton",{Parent=root,Text="R",Position=UDim2.fromOffset(600,600),Size=UDim2.fromOffset(100,40),Rotation=90,ZIndex=50})
    local child=UI.new("Frame",{Parent=f,Size=UDim2.fromOffset(10,10),Rotation=15})
    UI.Refresh()
    near(f.AbsoluteRotation,90); near(child.AbsoluteRotation,105)
    -- 90 degrees around the centre (650,620): the box becomes 40 wide x 100 tall.
    local sq=visibleDraws(f,"Square")[1]
    near(sq.Position.X,630); near(sq.Position.Y,570); near(sq.Size.X,40); near(sq.Size.Y,100)
    -- Text stays upright, centred on the rotated centre.
    local txt=visibleDraws(f,"Text")[1]; assert(txt and math.abs(txt.Position.Y+txt.Size/2-620)<txt.Size)
    -- Hit testing follows the rotation: (650,580) is inside the rotated box, (610,620) is not.
    assert(table.find(UI.GetGuiObjectsAtPosition(650,580),f))
    assert(not table.find(UI.GetGuiObjectsAtPosition(610,620),f))
    -- 45 degrees: Quads, no Squares.
    f.Rotation=45; UI.Refresh()
    assert(#visibleDraws(f,"Square")==0 and #visibleDraws(f,"Quad")>0)
    f.Rotation=0; UI.Refresh()
    assert(#visibleDraws(f,"Square")>0)
    f:Destroy()
end)
check("builder: sugar, named children, events, refs, OnChange",function()
    local ref, clicked, changes = {}, 0, 0
    local card=UI.New "Frame" {
        Parent=root, Position=UDim2.fromOffset(600,600), Size=UDim2.fromOffset(200,100), ZIndex=40,
        Corner=12, Stroke=Color3.new(1,1,1), Padding=10, Shadow=true, List=4,
        Gradient={Color3.new(1,1,1),Color3.new(0.5,0.5,0.5)},
        [UI.Children]={
            Title=UI.New "TextLabel" {Text="Hi",Size=UDim2.new(1,0,0,20)},
            UI.New "TextButton" {Text="Go",Size=UDim2.new(1,0,0,30),Activated=function() clicked+=1 end,[UI.Ref]=ref},
        },
    }
    assert(card.Parent==root and card:FindFirstChildOfClass("UICorner").CornerRadius.Offset==12)
    assert(card:FindFirstChildOfClass("UIStroke") and card:FindFirstChildOfClass("UIShadow") and card:FindFirstChildOfClass("UIGradient"))
    assert(card:FindFirstChildOfClass("UIPadding").PaddingLeft.Offset==10 and card:FindFirstChildOfClass("UIListLayout").Padding.Offset==4)
    assert(card.Title.Text=="Hi" and ref.value.Text=="Go")
    UI.Refresh(); near(card.Title.AbsolutePosition.Y,610); near(ref.value.AbsolutePosition.Y,634)
    click(700,645); assert(clicked==1)
    UI.Hydrate(card) {[UI.OnChange "BackgroundTransparency"]=function() changes+=1 end}
    card.BackgroundTransparency=0.5; assert(changes==1)
    assert(not pcall(function() UI.New "Frame" {Typo=1} end))
    assert(card:IsA("GuiObject") and not root:IsA("GuiObject") and ref.value:IsA("GuiButton"))
    card:Destroy()
end)
check("UIListLayout.Wraps and UITextSizeConstraint",function()
    local holder=UI.New "Frame" {Parent=root,Position=UDim2.fromOffset(600,600),Size=UDim2.fromOffset(100,100),
        List={FillDirection="Horizontal",Wraps=true,Padding=UDim.new(0,10)}}
    local items={}
    for i=1,3 do items[i]=UI.New "Frame" {Parent=holder,Size=UDim2.fromOffset(40,20),LayoutOrder=i} end
    UI.Refresh()
    near(items[2].AbsolutePosition.X,650); near(items[3].AbsolutePosition.X,600); near(items[3].AbsolutePosition.Y,630)
    local label=UI.New "TextLabel" {Parent=root,Text="Big",TextScaled=true,Position=UDim2.fromOffset(600,750),
        Size=UDim2.fromOffset(300,40),TextSizeLimit={MaxTextSize=14}}
    UI.Refresh()
    local size; for _,props in ipairs(visibleDraws(label,"Text")) do size=props.Size end
    assert(size==14, tostring(size))
    holder:Destroy(); label:Destroy()
end)
check("ScreenGui.Enabled hides drawings and disables clicks",function()
    root.Enabled=false; UI.Refresh()
    for _,d in ipairs(allDraws) do if not d.isDead() then assert(not d.data.Visible) end end
    local old=clicks; click(90,450); assert(clicks==old)
    root.Enabled=true; UI.Refresh()
end)
check("full cleanup and reconnect",function()
    UI.Destroy(); assert(drawingCreated==drawingDestroyed)
    assert(UI.GetStats().Connections==0 and UI.GetStats().Objects==0)
    local r=UI.new("ScreenGui"); UI.new("TextLabel",{Parent=r,Text="Restart"}); UI.Refresh()
    assert(UI.GetStats().Connections==5); UI.Destroy(); assert(drawingCreated==drawingDestroyed)
end)
check("demo factory, all tabs, hotkey, rerun and cleanup",function()
    local demo=createDemo(UI); UI.Refresh(); assert(demo.Root.Enabled)
    -- Demo coordinates: (225,145) window top-left on a 1200x800 viewport.
    click(270,303); assert(demo.Pages.Controls.Visible)
    click(270,348); assert(demo.Pages.Layout.Visible)
    key("RightShift"); assert(not demo.Root.Enabled); key("RightShift"); assert(demo.Root.Enabled)
    local old=demo; demo=createDemo(UI); assert(old.Root._dead and not demo.Root._dead)
    demo.Cleanup(); assert(drawingCreated==drawingDestroyed)
end)
assert(#warnings==0, table.concat(warnings,"\n"))
print(string.format("%d tests passed; %d Drawings created, %d destroyed; zero leaks",passed,drawingCreated,drawingDestroyed))
