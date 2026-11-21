-- Classes/TextBox: focus + keyboard editing live in Input/Input.
return function(UI, ctx)
    UI.RegisterClass("TextBox", {
        Base = "GuiObject", IsText = true,
        Defaults = function(p)
            ctx.textDefaults(p, "")
            p.PlaceholderText = ""; p.PlaceholderColor3 = Color3.fromRGB(140, 146, 165)
            p.ClearTextOnFocus = false; p.MultiLine = false; p.MaxLength = 4096
            p.TextEditable = true; p.Active = true; p.CursorPosition = -1
        end,
        Hittable = function() return true end,
        PreChildren = function(n, info) ctx.textPreChildren(n, info) end,
        Draw = function(n, style) ctx.drawText(n, style) end,
    })
end
