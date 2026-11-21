-- Classes/ScreenGui: top-level container sized to the viewport. Creating one starts the renderer.
return function(UI, ctx)
    UI.RegisterClass("ScreenGui", {
        Base = "GuiBase", Root = true,
        Defaults = function(p)
            p.Enabled = true; p.DisplayOrder = 0; p.IgnoreGuiInset = true
            p.BackgroundTransparency = 1; p.Size = UDim2.fromScale(1, 1)
        end,
    })
end
