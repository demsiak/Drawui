-- Classes/ImageLabel and ImageButton. Image is passed to Drawing Image.Data.
return function(UI, ctx)
    UI.RegisterClass("ImageLabel", {
        Base = "GuiObject",
        Defaults = function(p) ctx.imageDefaults(p) end,
        Draw = function(n, style) ctx.drawImage(n, style) end,
    })
    UI.RegisterClass("ImageButton", {
        Base = "GuiButton",
        Defaults = function(p) ctx.imageDefaults(p) end,
        Draw = function(n, style) ctx.drawImage(n, style) end,
    })
end
