-- Classes/Base: abstract hierarchy.
--   Instance
--   ├─ GuiBase (rendered, holds children)
--   │   ├─ ScreenGui
--   │   └─ GuiObject ── GuiButton
--   ├─ UIComponent (modifiers) ── UIConstraint, UILayout
return function(UI, ctx)
    local U = ctx.U

    UI.RegisterClass("Instance", { Abstract = true })

    UI.RegisterClass("GuiBase", {
        Base = "Instance", Abstract = true, Gui = true,
        Defaults = function(p)
            p.Visible = true; p.Active = false; p.Interactable = true
            p.Position = UDim2.new(); p.Size = UDim2.fromOffset(100, 100); p.AnchorPoint = U.ZERO
            p.BackgroundColor3 = Color3.fromRGB(30, 33, 43); p.BackgroundTransparency = 0
            p.BorderColor3 = Color3.fromRGB(64, 69, 85); p.BorderSizePixel = 0
            p.ZIndex = 1; p.LayoutOrder = 0; p.ClipsDescendants = false; p.AutomaticSize = "None"
            p.AbsolutePosition = U.ZERO; p.AbsoluteSize = U.ZERO
        end,
        Hittable = function(n) return n._p.Active end,
    })

    UI.RegisterClass("GuiObject", { Base = "GuiBase", Abstract = true })

    UI.RegisterClass("GuiButton", {
        Base = "GuiObject", Abstract = true,
        Defaults = { AutoButtonColor = true, Active = true },
        Hittable = function() return true end,
        Style = function(n, style)
            local p = n._p
            if not (p.AutoButtonColor and p.Interactable) then return end
            if ctx.pressed == n then style.background = U.mix(style.background, U.BLACK, 0.22)
            elseif ctx.hovered == n then style.background = U.mix(style.background, U.WHITE, 0.10) end
        end,
    })

    UI.RegisterClass("UIComponent", { Base = "Instance", Abstract = true, Modifier = true })
    UI.RegisterClass("UIConstraint", { Base = "UIComponent", Abstract = true })
    UI.RegisterClass("UILayout", {
        Base = "UIComponent", Abstract = true,
        ReadOnly = { AbsoluteContentSize = true },
        Defaults = function(p)
            p.FillDirection = "Vertical"; p.SortOrder = "LayoutOrder"
            p.HorizontalAlignment = "Left"; p.VerticalAlignment = "Top"; p.AbsoluteContentSize = U.ZERO
        end,
    })

    -- Shared defaults for TextLabel / TextButton / TextBox.
    function ctx.textDefaults(p, text)
        p.Text = text; p.TextColor3 = U.WHITE
        p.TextSize = 16; p.Font = 0; p.TextTransparency = 0; p.TextBounds = U.ZERO
        p.TextXAlignment = "Center"; p.TextYAlignment = "Center"
        p.TextWrapped = false; p.TextScaled = false; p.LineHeight = 1.15
        p.TextStrokeTransparency = 1; p.TextStrokeColor3 = U.BLACK
    end
    ctx.readonly.TextBounds = true

    -- Shared defaults for ImageLabel / ImageButton.
    function ctx.imageDefaults(p)
        p.Image = ""; p.ImageColor3 = U.WHITE; p.ImageTransparency = 0
    end
    -- Image draw hook. Drawing has no UV/scissor API, so partially clipped images are hidden.
    function ctx.drawImage(n, style)
        local p = n._p
        if p.Image == "" or not ctx.fullyInside(style.area, style.clip) then return end
        local color, alpha = U.multiply(p.ImageColor3, style.tint), style.opacity * (1 - p.ImageTransparency)
        if style.gradient and style.gradient.ApplyToText then
            local c, a = ctx.gradientAt(style.gradient, 0.5)
            color, alpha = U.multiply(color, c), alpha * a
        end
        if alpha <= 0 then return end
        ctx.primitive(n, "Image", { Data = p.Image, Position = style.pos, Size = style.size, Rounding = style.radius,
            Color = color, Transparency = U.clamp(alpha, 0, 1) })
    end
end
