-- Classes/TextButton
return function(UI, ctx)
    UI.RegisterClass("TextButton", {
        Base = "GuiButton", IsText = true,
        Defaults = function(p) ctx.textDefaults(p, "TextButton") end,
        PreChildren = function(n, info) ctx.textPreChildren(n, info) end,
        Draw = function(n, style) ctx.drawText(n, style) end,
    })
end
