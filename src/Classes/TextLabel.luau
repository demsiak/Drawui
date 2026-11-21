-- Classes/TextLabel
return function(UI, ctx)
    UI.RegisterClass("TextLabel", {
        Base = "GuiObject", IsText = true,
        Defaults = function(p) ctx.textDefaults(p, "TextLabel"); p.BackgroundTransparency = 1 end,
        PreChildren = function(n, info) ctx.textPreChildren(n, info) end,
        Draw = function(n, style) ctx.drawText(n, style) end,
    })
end
