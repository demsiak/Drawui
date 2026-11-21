-- Classes/Frame and CanvasGroup.
return function(UI, ctx)
    local U = ctx.U
    UI.RegisterClass("Frame", { Base = "GuiObject" })

    -- CanvasGroup fades and tints its whole subtree.
    UI.RegisterClass("CanvasGroup", {
        Base = "GuiObject",
        Defaults = function(p) p.GroupTransparency = 0; p.GroupColor3 = U.WHITE end,
        Style = function(n, style)
            style.opacity *= 1 - n._p.GroupTransparency
            style.tint = U.multiply(style.tint, n._p.GroupColor3)
        end,
    })
end
