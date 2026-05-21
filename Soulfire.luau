--[[
    Interface.luau — Unified, fully independent Soulfire UI Library.

    Provides:
      • Interface.New()          — thin Instance.new() wrapper with defaults & inline children
      • Interface.GetIcon()      — fetch a Lucide icon by name
      • Interface.GetCustomIcon() — resolve a custom asset id / url or fall back to Lucide
      • Interface.Animations     — Preset animations (FadeIn, FadeOut, SlideIn, SlideOut, Pop, Pulse)
      • Interface.KeyInterface   — Main authentication UI class
      • Interface.Sonner         — Notification system with smooth programmatic transitions
]]

local Interface = {}

-- ======================== DEFAULT PROPERTIES ========================

local DefaultProperties = {
    ["Frame"] = {
        BorderSizePixel = 0,
    },
    ["ScrollingFrame"] = {
        BorderSizePixel = 0,
    },
    ["ImageLabel"] = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    },
    ["ImageButton"] = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    },
    ["TextLabel"] = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        RichText = true,
        TextColor3 = Color3.new(1, 1, 1),
    },
    ["TextButton"] = {
        AutoButtonColor = false,
        BorderSizePixel = 0,
        FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        RichText = true,
        TextColor3 = Color3.new(1, 1, 1),
    },
    ["TextBox"] = {
        BorderSizePixel = 0,
        FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        ClipsDescendants = true,
        RichText = false,
        TextColor3 = Color3.new(1, 1, 1),
    },
    ["UIListLayout"] = {
        SortOrder = Enum.SortOrder.LayoutOrder,
    },
}

-- ======================== UTILITIES ========================

local gethui = gethui and gethui() or function() return game:GetService("CoreGui") end

-- ======================== ICON TYPES ========================

type Icon = {
    Url: string,
    Id: number,
    IconName: string,
    ImageRectOffset: Vector2,
    ImageRectSize: Vector2,
}

type IconModule = {
    Icons: { string },
    GetAsset: (Name: string) -> Icon?,
}

local FetchIcons, Icons = pcall(function()
    return (loadstring(
        game:HttpGet("https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua")
    ) :: () -> IconModule)()
end)

local function IsValidCustomIcon(Icon: string)
    return typeof(Icon) == "string" and (Icon:match("rbxasset") or Icon:match("roblox%.com/asset/%?id=") or Icon:match("rbxthumb://type="))
end

-- ======================== FACTORY METHODS ========================

--- Creates a new Instance with default properties merged under explicit ones.
--- Table-valued entries are treated as inline children (key = ClassName, value = props).
--- Numeric entries with Instance values are cloned and parented.
function Interface.New(ClassName: string, Properties: { [string | number]: any }?): Instance
    local Object = Instance.new(ClassName)

    -- Apply defaults (only if not explicitly overridden)
    for Key, Value in pairs(DefaultProperties[ClassName] or {}) do
        if Properties and Properties[Key] ~= nil then
            continue
        end
        Object[Key] = Value
    end

    -- Apply explicit properties / create inline children
    for Key, Value in pairs(Properties or {}) do
        if typeof(Value) == "table" then
            local SubObject = Interface.New(Key, Value)
            SubObject.Parent = Object
            continue
        elseif typeof(Key) ~= "string" and typeof(Value) == "Instance" then
            local SubObject = Value:Clone()
            SubObject.Parent = Object
            continue
        end
        Object[Key] = Value
    end

    return Object
end

-- Get an icon from the lucide icon set.
function Interface.GetIcon(IconName: string): any
    if not FetchIcons then
        return
    end

    local Success, Icon = pcall(Icons.GetAsset, IconName)
    if not Success then
        return
    end
    return Icon
end

function Interface.GetCustomIcon(IconName: string): any
    if not IconName then
        return nil
    end

    if tonumber(IconName) then
        IconName = string.format("rbxassetid://%s", tostring(IconName))
    end

    local CustomIcon = IsValidCustomIcon(IconName)
    if CustomIcon then
        return {
            Url = IconName,
            ImageRectOffset = Vector2.zero,
            ImageRectSize = Vector2.zero,
            Custom = true,
        }
    end

    local LucideIcon = Interface.GetIcon(IconName)
    if LucideIcon then
        return LucideIcon
    end

    return nil
end

-- ======================== PRESET ANIMATIONS ========================

local TweenService = game:GetService("TweenService")

local Animations = {}
Interface.Animations = Animations

local function _tween(obj: Instance, tweenInfo: TweenInfo, goals: { [string]: any })
    local ok, t = pcall(TweenService.Create, TweenService, obj, tweenInfo, goals)
    return ok and t or nil
end

--- Fade an object in (GroupTransparency → 0, or BackgroundTransparency → 0).
function Animations.FadeIn(obj: GuiObject, duration: number?)
    local t = duration or 0.3
    local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    if obj:IsA("CanvasGroup") then
        obj.GroupTransparency = 1
        return _tween(obj, info, { GroupTransparency = 0 })
    else
        local savedTrans = obj.BackgroundTransparency
        obj.BackgroundTransparency = 1
        return _tween(obj, info, { BackgroundTransparency = savedTrans })
    end
end

--- Fade an object out (GroupTransparency → 1, or BackgroundTransparency → 1).
function Animations.FadeOut(obj: GuiObject, duration: number?)
    local t = duration or 0.3
    local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    if obj:IsA("CanvasGroup") then
        return _tween(obj, info, { GroupTransparency = 1 })
    else
        return _tween(obj, info, { BackgroundTransparency = 1 })
    end
end

--- Slide an object in from a direction to its current Position.
function Animations.SlideIn(obj: GuiObject, direction: string, distance: number, duration: number)
    direction = direction or "up"
    distance  = distance  or 24
    local t   = duration  or 0.35
    local info = TweenInfo.new(t, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    local origin = obj.Position
    local dx, dy = 0, 0
    if direction == "up"    then dy =  distance end
    if direction == "down"  then dy = -distance end
    if direction == "left"  then dx =  distance end
    if direction == "right" then dx = -distance end

    obj.Position = UDim2.new(
        origin.X.Scale, origin.X.Offset + dx,
        origin.Y.Scale, origin.Y.Offset + dy
    )
    return _tween(obj, info, { Position = origin })
end

--- Slide an object out in a direction from its current Position.
function Animations.SlideOut(obj: GuiObject, direction: string, distance: number, duration: number)
    direction = direction or "down"
    distance  = distance  or 24
    local t   = duration  or 0.3
    local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

    local origin = obj.Position
    local dx, dy = 0, 0
    if direction == "up"    then dy = -distance end
    if direction == "down"  then dy =  distance end
    if direction == "left"  then dx = -distance end
    if direction == "right" then dx =  distance end

    return _tween(obj, info, {
        Position = UDim2.new(
            origin.X.Scale, origin.X.Offset + dx,
            origin.Y.Scale, origin.Y.Offset + dy
        )
    })
end

--- Quick scale-up-then-settle pop. Requires a UIScale child (created if absent).
function Animations.Pop(obj: GuiObject, scale: number, duration: number)
    scale    = scale    or 1.08
    duration = duration or 0.2

    local uiScale = obj:FindFirstChildOfClass("UIScale")
    if not uiScale then
        uiScale = Instance.new("UIScale")
        uiScale.Parent = obj
    end

    local inInfo  = TweenInfo.new(duration * 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local outInfo = TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

    local tw1 = _tween(uiScale, inInfo,  { Scale = scale })
    local tw2 = _tween(uiScale, outInfo, { Scale = 1 })

    if tw1 then
        tw1:Play()
        tw1.Completed:Connect(function()
            if tw2 then tw2:Play() end
        end)
    end
    return tw2
end

-- ======================== KEY INTERFACE ========================

local KeyInterface = {}
KeyInterface.__index = KeyInterface
Interface.KeyInterface = KeyInterface

local Palette = {
    bg_primary = Color3.fromRGB(36, 32, 95),
    bg_secondary = Color3.fromRGB(67, 60, 136),
    button_primary = Color3.fromRGB(144, 135, 254),
    button_hover = Color3.fromRGB(160, 150, 270),
    accent_gold = Color3.fromRGB(241, 192, 68),
    text_primary = Color3.fromRGB(36, 32, 95),
    text_white = Color3.fromRGB(255, 255, 255),
    notification_info = Color3.fromRGB(100, 150, 255),
    notification_success = Color3.fromRGB(100, 200, 100),
    notification_error = Color3.fromRGB(200, 100, 100),
    notification_warning = Color3.fromRGB(255, 255, 75),
    notification_searching = Color3.fromRGB(100, 150, 255),
}

-- Delegate
KeyInterface.New = Interface.New
KeyInterface.GetCustomIcon = Interface.GetCustomIcon
KeyInterface.GetIcon = Interface.GetIcon

function KeyInterface:Destroy()
    if self._destroyed then return end
    self._destroyed = true

    -- Disconnect all tracked connections
    for _, conn in pairs(self._connections or {}) do
        pcall(function() conn:Disconnect() end)
    end
    self._connections = {}

    -- Destroy root GUI
    if self.UI and self.UI.Root then
        self.UI.Root:Destroy()
    end
    self.UI = nil
end

function KeyInterface:_track(connection)
    table.insert(self._connections, connection)
    return connection
end

function KeyInterface.new(config: { [string]: any }?)
    local self = setmetatable({}, KeyInterface)
    self.UI = {}
    self._connections = {}
    self._destroyed = false
    self._config = config or {}

    self:_buildUI()
    self:_applyEffects()
    self:_bindEvents()

    self:makeDraggable(self.UI["Mainframe"])

    return self
end

function KeyInterface:_buildUI()
    -- Root ScreenGui
    self.UI["Root"] = Interface.New("ScreenGui", {
        Name = "SoulfireKeyUi",
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = gethui(),
    })

    -- Mainframe
    self.UI["Mainframe"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        BackgroundColor3 = Palette.bg_primary,
        AnchorPoint = Vector2.new(0.5, 0.5),
        ClipsDescendants = true,
        Size = UDim2.new(0.4675, 0, 0.72625, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Name = "Mainframe",
        Parent = self.UI["Root"],
    })

    -- Mainframe UIStroke
    self.UI["Mainframe_UIStroke"] = Interface.New("UIStroke", {
        Thickness = 4,
        Color = Palette.bg_secondary,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = self.UI["Mainframe"],
    })

    -- Mainframe UICorner
    self.UI["Mainframe_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0.15, 0),
        Parent = self.UI["Mainframe"],
    })

    -- Topbar
    self.UI["Topbar"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        Size = UDim2.new(0.99491, 0, 0.26435, 0),
        Position = UDim2.new(0.00254, 0, 0.00302, 0),
        Name = "Topbar",
        BackgroundTransparency = 1,
        Parent = self.UI["Mainframe"],
    })

    -- Title Container
    self.UI["Title"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        Size = UDim2.new(0.4121, 0, 0.64939, 0),
        Position = UDim2.new(0.06031, 0, 0.30263, 0),
        Name = "Title",
        BackgroundTransparency = 1,
        Parent = self.UI["Topbar"],
    })

    -- Logo Container
    self.UI["LogoContainer"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        Size = UDim2.new(0.30488, 0, 0.97087, 0),
        Position = UDim2.new(0, 0, 0.01942, 0),
        Name = "LogoContainer",
        BackgroundTransparency = 1,
        Parent = self.UI["Title"],
    })

    -- Logo Image
    self.UI["Logo"] = Interface.New("ImageLabel", {
        Active = true,
        BorderSizePixel = 0,
        Image = "rbxassetid://113862788178083",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Name = "Logo",
        Parent = self.UI["LogoContainer"],
    })

    -- Logo Glow
    self.UI["LogoGlow"] = Interface.New("ImageLabel", {
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ImageColor3 = Color3.fromRGB(48, 142, 255),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Image = "rbxassetid://110710891952891",
        Size = UDim2.new(1.5, 0, 1.5, 0),
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Name = "glow",
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Parent = self.UI["Logo"],
    })

    -- Text Container
    self.UI["TextContainer"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        Size = UDim2.new(0.62195, 0, 1, 0),
        Position = UDim2.new(0.37805, 0, 0, 0),
        Name = "TextContainer",
        BackgroundTransparency = 1,
        Parent = self.UI["Title"],
    })

    -- Header Background
    self.UI["HeaderBg"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        BackgroundColor3 = Palette.button_primary,
        Size = UDim2.new(0.64216, 0, 0.28155, 0),
        Position = UDim2.new(0.01961, 0, 0.67961, 0),
        Name = "Header",
        Parent = self.UI["TextContainer"],
    })

    -- Header Label
    self.UI["HeaderLabel"] = Interface.New("TextLabel", {
        TextWrapped = true,
        Active = true,
        TextTruncate = Enum.TextTruncate.SplitWord,
        BorderSizePixel = 0,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextScaled = true,
        FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        TextColor3 = Palette.text_white,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.76782, 0, 0.51724, 0),
        Text = "Easy Key System",
        Name = "Label",
        Position = UDim2.new(0.09924, 0, 0.2069, 0),
        Parent = self.UI["HeaderBg"],
    })

    -- Main Title
    self.UI["MainTitle"] = Interface.New("TextLabel", {
        TextWrapped = true,
        Active = true,
        BorderSizePixel = 0,
        TextSize = 58,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextScaled = true,
        FontFace = Font.new("rbxasset://fonts/families/PermanentMarker.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
        TextColor3 = Color3.fromRGB(135, 125, 255),
        BackgroundTransparency = 1,
        Size = UDim2.new(1.23529, 0, 0.67961, 0),
        Text = "Soulfire",
        Name = "Label",
        Parent = self.UI["TextContainer"],
    })

    -- Exit Button
    self.UI["ExitButton"] = Interface.New("ImageButton", {
        BorderSizePixel = 0,
        AutoButtonColor = false,
        BackgroundColor3 = Palette.button_primary,
        Selectable = false,
        Size = UDim2.new(0.05026, 0, 0.25219, 0),
        ClipsDescendants = true,
        Name = "ExitButton",
        Position = UDim2.new(0.85184, 0, 0.45394, 0),
        Parent = self.UI["Topbar"],
    })
    self.UI["ExitButton"]:SetAttribute("HoverFx", true)

    -- Exit Button Corner
    self.UI["ExitButton_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0, 100),
        Parent = self.UI["ExitButton"],
    })

    -- Exit Button Icon
    self.UI["ExitButtonIcon"] = Interface.New("ImageLabel", {
        Active = true,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Image = "rbxassetid://96295731636759",
        Size = UDim2.new(0.42424, 0, 0.42424, 0),
        BackgroundTransparency = 1,
        Name = "icon",
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Parent = self.UI["ExitButton"],
    })

    -- Premium Section
    self.UI["Premium"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0.875, 0, 0.21804, 0),
        Position = UDim2.new(0.49947, 0, 0.81477, 0),
        Name = "Premium",
        Parent = self.UI["Mainframe"],
    })

    -- Premium Gradient
    self.UI["Premium_UIGradient"] = Interface.New("UIGradient", {
        Color = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Palette.button_primary),ColorSequenceKeypoint.new(1.000, Palette.button_primary)},
        Parent = self.UI["Premium"],
    })

    -- Premium Corner
    self.UI["Premium_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0, 48),
        Parent = self.UI["Premium"],
    })

    -- Buy Button
    self.UI["BuyButton"] = Interface.New("TextButton", {
        TextWrapped = true,
        BorderSizePixel = 0,
        TextSize = 1,
        AutoButtonColor = false,
        TextScaled = true,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(0.11516, 0, 0.35, 0),
        Text = "",
        Name = "BuyButton",
        Position = UDim2.new(0.83819, 0, 0.325, 0),
        Parent = self.UI["Premium"],
    })
    self.UI["BuyButton"]:SetAttribute("ClickFx", true)
    self.UI["BuyButton"]:SetAttribute("HoverFx", true)

    -- Buy Button Corner
    self.UI["BuyButton_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0, 10),
        Parent = self.UI["BuyButton"],
    })

    -- Buy Button Stroke
    self.UI["BuyButton_UIStroke"] = Interface.New("UIStroke", {
        Thickness = 5,
        Color = Color3.fromRGB(255, 255, 255),
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        BorderStrokePosition = Enum.BorderStrokePosition.Center,
        Parent = self.UI["BuyButton"],
    })

    -- Buy Button Stroke Gradient
    self.UI["BuyButton_Stroke_Gradient"] = Interface.New("UIGradient", {
        Rotation = -143.806,
        Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0.000, 0),NumberSequenceKeypoint.new(0.500, 0),NumberSequenceKeypoint.new(1.000, 0)},
        Color = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Palette.accent_gold),ColorSequenceKeypoint.new(0.500, Color3.fromRGB(253, 247, 187)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(219, 166, 33))},
        Parent = self.UI["BuyButton_UIStroke"],
    })

    -- Buy Button Label
    self.UI["BuyButton_Label"] = Interface.New("TextLabel", {
        TextWrapped = true,
        Active = true,
        BorderSizePixel = 0,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextScaled = true,
        FontFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
        TextColor3 = Palette.text_primary,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0.39241, 0, 0.42857, 0),
        Text = "BUY",
        Name = "Label",
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Parent = self.UI["BuyButton"],
    })

    -- Premium Container
    self.UI["PremiumContainer"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0.50429, 0, 0.558, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Name = "Container",
        BackgroundTransparency = 1,
        Parent = self.UI["Premium"],
    })

    -- Premium Title
    self.UI["PremiumTitle"] = Interface.New("TextLabel", {
        TextWrapped = true,
        Active = true,
        BorderSizePixel = 0,
        TextSize = 29,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextScaled = true,
        FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
        TextColor3 = Palette.text_primary,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.63456, 0, 0.57534, 0),
        Text = "Soulfire Premium",
        Name = "Title",
        Parent = self.UI["PremiumContainer"],
    })

    -- Premium Description
    self.UI["PremiumDesc"] = Interface.New("TextLabel", {
        TextWrapped = true,
        Active = true,
        BorderSizePixel = 0,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 0.64,
        TextScaled = true,
        FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
        TextColor3 = Palette.text_primary,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.84986, 0, 0.27397, 0),
        Text = "Keyless | OP features | Priority Support",
        Name = "Label",
        Position = UDim2.new(0.03966, 0, 0.63014, 0),
        Parent = self.UI["PremiumContainer"],
    })

    -- Premium Dot
    self.UI["PremiumDot"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        BackgroundColor3 = Palette.text_primary,
        Size = UDim2.new(0.01983, 0, 0.09589, 0),
        Position = UDim2.new(0, 0, 0.72603, 0),
        Name = "Dot",
        BackgroundTransparency = 0.6,
        Parent = self.UI["PremiumContainer"],
    })

    -- Dot Corner
    self.UI["PremiumDot_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0, 9999),
        Parent = self.UI["PremiumDot"],
    })

    -- Premium Overlay
    self.UI["PremiumOverlay"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        BackgroundColor3 = Palette.text_primary,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0.12143, 0, 0.64972, 0),
        Position = UDim2.new(0.11421, 0, 0.49423, 0),
        Name = "Overlay",
        BackgroundTransparency = 0.9,
        Parent = self.UI["Premium"],
    })

    -- Overlay Corner
    self.UI["PremiumOverlay_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0, 24),
        Parent = self.UI["PremiumOverlay"],
    })

    -- Overlay Icon
    self.UI["PremiumOverlay_Icon"] = Interface.New("ImageLabel", {
        Active = true,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Image = "rbxassetid://76027272264854",
        Size = UDim2.new(0.8, 0, 0.8, 0),
        BackgroundTransparency = 1,
        Name = "Icon",
        Position = UDim2.new(0.5, 0, 0.49068, 0),
        Parent = self.UI["PremiumOverlay"],
    })

    -- Icon Gradient
    self.UI["PremiumOverlay_IconGradient"] = Interface.New("UIGradient", {
        Name = "UIToolsGradient",
        Color = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(255, 217, 165)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(219, 196, 103))},
        Parent = self.UI["PremiumOverlay_Icon"],
    })

    -- Overlay Aspect Ratio
    self.UI["PremiumOverlay_AspectRatio"] = Interface.New("UIAspectRatioConstraint", {
        Parent = self.UI["PremiumOverlay"],
    })

    -- Overlay Stroke
    self.UI["PremiumOverlay_UIStroke"] = Interface.New("UIStroke", {
        Thickness = 2,
        Color = Color3.fromRGB(116, 108, 212),
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = self.UI["PremiumOverlay"],
    })

    -- Premium Aspect Ratio
    self.UI["Premium_AspectRatio"] = Interface.New("UIAspectRatioConstraint", {
        AspectRatio = 5.35067,
        Parent = self.UI["Premium"],
    })

    -- Premium Stroke
    self.UI["Premium_UIStroke"] = Interface.New("UIStroke", {
        Thickness = 4,
        Color = Color3.fromRGB(255, 255, 255),
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = self.UI["Premium"],
    })

    -- Premium Stroke Gradient
    self.UI["Premium_Stroke_Gradient"] = Interface.New("UIGradient", {
        Rotation = -75,
        Color = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(223, 197, 138)),ColorSequenceKeypoint.new(0.500, Color3.fromRGB(247, 233, 165)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(210, 180, 115))},
        Parent = self.UI["Premium_UIStroke"],
    })

    -- Premium Stars
    self.UI["PremiumStars"] = Interface.New("ImageLabel", {
        ZIndex = 0,
        BorderSizePixel = 0,
        ScaleType = Enum.ScaleType.Tile,
        BackgroundColor3 = Color3.fromRGB(31, 31, 31),
        ImageTransparency = 0.95,
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        Image = "rbxassetid://279798627",
        TileSize = UDim2.new(0, 30, 0, 30),
        Size = UDim2.new(1, 0, 1, 0),
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Name = "Stars",
        Parent = self.UI["Premium"],
    })

    -- Divider
    self.UI["Divider"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(250, 225, 250),
        Size = UDim2.new(0.72519, 0, 0.00151, 0),
        Position = UDim2.new(0.1374, 0, 0.64955, 0),
        Name = "Divider",
        Parent = self.UI["Mainframe"],
    })

    -- Get Key Button
    self.UI["GetKeyButton"] = Interface.New("ImageButton", {
        BorderSizePixel = 0,
        AutoButtonColor = false,
        BackgroundColor3 = Palette.button_primary,
        Selectable = false,
        Size = UDim2.new(0.42621, 0, 0.12085, 0),
        ClipsDescendants = true,
        Name = "GetKeyButton",
        Position = UDim2.new(0.06361, 0, 0.48187, 0),
        Parent = self.UI["Mainframe"],
    })
    self.UI["GetKeyButton"]:SetAttribute("HoverFx", true)
    self.UI["GetKeyButton"]:SetAttribute("ClickFx", true)

    -- Get Key Button Stroke
    self.UI["GetKeyButton_UIStroke"] = Interface.New("UIStroke", {
        Thickness = 3,
        Color = Palette.bg_secondary,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        BorderStrokePosition = Enum.BorderStrokePosition.Inner,
        Parent = self.UI["GetKeyButton"],
    })

    -- Get Key Button Corner
    self.UI["GetKeyButton_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0, 50),
        Parent = self.UI["GetKeyButton"],
    })

    -- Get Key Button Icon
    self.UI["GetKeyButton_Icon"] = Interface.New("ImageLabel", {
        Active = true,
        BorderSizePixel = 0,
        ImageColor3 = Color3.fromRGB(65025, 65025, 65025),
        Image = "rbxassetid://78800220063925",
        Size = UDim2.new(0.06746, 0, 0.31721, 0),
        BackgroundTransparency = 1,
        Name = "Icon",
        Position = UDim2.new(0.2627, 0, 0.331, 0),
        Parent = self.UI["GetKeyButton"],
    })

    -- Get Key Button Label
    self.UI["GetKeyButton_Label"] = Interface.New("TextLabel", {
        TextWrapped = true,
        Active = true,
        BorderSizePixel = 0,
        TextSize = 25,
        TextTransparency = 0.5,
        TextScaled = true,
        FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        TextColor3 = Palette.text_primary,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.56301, 0, 0.41375, 0),
        Text = "Get Key",
        Name = "Label",
        Position = UDim2.new(0.21577, 0, 0.2916, 0),
        Parent = self.UI["GetKeyButton"],
    })

    -- Get Key Button Aspect Ratio
    self.UI["GetKeyButton_AspectRatio"] = Interface.New("UIAspectRatioConstraint", {
        AspectRatio = 4.7025,
        Parent = self.UI["GetKeyButton"],
    })

    -- Check Key Button
    self.UI["CheckKeyButton"] = Interface.New("ImageButton", {
        BorderSizePixel = 0,
        AutoButtonColor = false,
        BackgroundColor3 = Palette.button_primary,
        Selectable = false,
        Size = UDim2.new(0.42621, 0, 0.12085, 0),
        ClipsDescendants = true,
        Name = "CheckKeyButton",
        Position = UDim2.new(0.51018, 0, 0.48187, 0),
        Parent = self.UI["Mainframe"],
    })
    self.UI["CheckKeyButton"]:SetAttribute("HoverFx", true)
    self.UI["CheckKeyButton"]:SetAttribute("ClickFx", true)

    -- Check Key Button Stroke
    self.UI["CheckKeyButton_UIStroke"] = Interface.New("UIStroke", {
        Thickness = 3,
        Color = Palette.bg_secondary,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        BorderStrokePosition = Enum.BorderStrokePosition.Inner,
        Parent = self.UI["CheckKeyButton"],
    })

    -- Check Key Button Corner
    self.UI["CheckKeyButton_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0, 50),
        Parent = self.UI["CheckKeyButton"],
    })

    -- Check Key Button Icon
    self.UI["CheckKeyButton_Icon"] = Interface.New("ImageLabel", {
        Active = true,
        BorderSizePixel = 0,
        ImageColor3 = Color3.fromRGB(65025, 65025, 65025),
        Image = "rbxassetid://72953745454814",
        Size = UDim2.new(0.06746, 0, 0.31721, 0),
        BackgroundTransparency = 1,
        Name = "Icon",
        Position = UDim2.new(0.242, 0, 0.331, 0),
        Parent = self.UI["CheckKeyButton"],
    })

    -- Check Key Button Icon Aspect Ratio
    self.UI["CheckKeyButton_Icon_AspectRatio"] = Interface.New("UIAspectRatioConstraint", {
        Parent = self.UI["CheckKeyButton_Icon"],
    })

    -- Check Key Button Label
    self.UI["CheckKeyButton_Label"] = Interface.New("TextLabel", {
        TextWrapped = true,
        Active = true,
        BorderSizePixel = 0,
        TextSize = 25,
        TextTransparency = 0.5,
        TextScaled = true,
        FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        TextColor3 = Palette.text_primary,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.59527, 0, 0.41375, 0),
        Text = "Check Key",
        Name = "Label",
        Position = UDim2.new(0.19943, 0, 0.27386, 0),
        Parent = self.UI["CheckKeyButton"],
    })

    -- Check Key Button Aspect Ratio
    self.UI["CheckKeyButton_AspectRatio"] = Interface.New("UIAspectRatioConstraint", {
        AspectRatio = 4.7025,
        Parent = self.UI["CheckKeyButton"],
    })

    -- Key Input Frame
    self.UI["KeyInput"] = Interface.New("Frame", {
        Active = true,
        BorderSizePixel = 0,
        BackgroundColor3 = Palette.button_primary,
        ClipsDescendants = true,
        Size = UDim2.new(0.875, 0, 0.15031, 0),
        Position = UDim2.new(0.06197, 0, 0.31969, 0),
        Name = "KeyInput",
        Parent = self.UI["Mainframe"],
    })

    -- Key Input Stroke
    self.UI["KeyInput_UIStroke"] = Interface.New("UIStroke", {
        Thickness = 4,
        Color = Palette.bg_secondary,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        BorderStrokePosition = Enum.BorderStrokePosition.Inner,
        Parent = self.UI["KeyInput"],
    })

    -- Key Input Corner
    self.UI["KeyInput_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0, 48),
        Parent = self.UI["KeyInput"],
    })

    -- Key Input TextBox
    self.UI["KeyInputBox"] = Interface.New("TextBox", {
        TextXAlignment = Enum.TextXAlignment.Left,
        PlaceholderColor3 = Palette.text_primary,
        BorderSizePixel = 0,
        TextWrapped = true,
        TextTransparency = 0.5,
        TextSize = 25,
        TextColor3 = Palette.text_primary,
        TextScaled = true,
        FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        Selectable = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        PlaceholderText = "Your Key Here",
        Size = UDim2.new(0.8, 0, 0.4, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Text = "",
        BackgroundTransparency = 1,
        Name = "TextBox",
        Parent = self.UI["KeyInput"],
    })
    self.UI["KeyInputBox"]:SetAttribute("InputFx", true)

    -- Key Input Icon
    self.UI["KeyInput_Icon"] = Interface.New("ImageLabel", {
        Active = true,
        BorderSizePixel = 0,
        ImageColor3 = Color3.fromRGB(65025, 65025, 65025),
        Image = "rbxassetid://126538875708943",
        Size = UDim2.new(0.03286, 0, 0.24394, 0),
        BackgroundTransparency = 1,
        Name = "Icon",
        Position = UDim2.new(0.05429, 0, 0.41026, 0),
        Parent = self.UI["KeyInput"],
    })

    -- Stripes
    self.UI["Stripes"] = Interface.New("ImageLabel", {
        ZIndex = 0,
        BorderSizePixel = 0,
        ScaleType = Enum.ScaleType.Tile,
        BackgroundColor3 = Color3.fromRGB(31, 31, 31),
        ImageTransparency = 0.95,
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        Image = "rbxassetid://87577631610763",
        TileSize = UDim2.new(0, 30, 0, 30),
        Size = UDim2.new(1, 0, 1, 0),
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Name = "Stripes",
        Parent = self.UI["Mainframe"],
    })

    -- Stripes Corner
    self.UI["Stripes_UICorner"] = Interface.New("UICorner", {
        CornerRadius = UDim.new(0.15, 0),
        Parent = self.UI["Stripes"],
    })

    -- Mainframe Size Constraint
    self.UI["Mainframe_SizeConstraint"] = Interface.New("UISizeConstraint", {
        MinSize = Vector2.new(300, 250),
        Parent = self.UI["Mainframe"],
    })

    -- Mainframe Aspect Ratio
    self.UI["Mainframe_AspectRatio"] = Interface.New("UIAspectRatioConstraint", {
        AspectRatio = 1.32202,
        Parent = self.UI["Mainframe"],
    })
end

function KeyInterface:makeDraggable(gui: GuiObject)
    local dragging
    local dragInput
    local dragStart
    local startPos

    local function update(input)
        local delta = input.Position - dragStart
        gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    self:_track(gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end))

    self:_track(gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    self:_track(game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end))
end

-- Private helpers for effects
local function applyHoverEffect(self, button, originalColor)
    self:_track(button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Palette.button_hover
    end))
    self:_track(button.MouseLeave:Connect(function()
        button.BackgroundColor3 = originalColor
    end))
end

local function applyClickEffect(self, button)
    local function createRing(position)
        local ring = Instance.new("Frame")
        ring.Name = "ClickRing"
        ring.BorderSizePixel = 0
        ring.BackgroundColor3 = Palette.button_primary
        ring.BackgroundTransparency = 0.5
        ring.Size = UDim2.new(0, 0, 0, 0)
        ring.Position = position
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Parent = button

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = ring

        local startTime = tick()
        local duration = 0.5

        local connection
        connection = game:GetService("RunService").RenderStepped:Connect(function()
            local elapsed = tick() - startTime
            local progress = math.min(elapsed / duration, 1)
            ring.Size = UDim2.new(0, 100 * progress, 0, 100 * progress)
            ring.BackgroundTransparency = 0.5 + (progress * 0.5)
            if progress >= 1 then
                connection:Disconnect()
                ring:Destroy()
            end
        end)
    end

    self:_track(button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local relativeX = input.Position.X - button.AbsolutePosition.X
            local relativeY = input.Position.Y - button.AbsolutePosition.Y
            createRing(UDim2.new(0, relativeX, 0, relativeY))
        end
    end))
end

local function applyInputEffect(self, textbox)
    local originalColor = textbox.Parent.BackgroundColor3
    self:_track(textbox.Focused:Connect(function()
        textbox.Parent.BackgroundColor3 = Palette.button_hover
    end))
    self:_track(textbox.FocusLost:Connect(function()
        textbox.Parent.BackgroundColor3 = originalColor
    end))
end

function KeyInterface:_applyEffects()
    for _, obj in pairs(self.UI) do
        if typeof(obj) == "Instance" and obj:IsA("GuiButton") then
            if obj:GetAttribute("HoverFx") then
                applyHoverEffect(self, obj, obj.BackgroundColor3)
            end
            if obj:GetAttribute("ClickFx") then
                applyClickEffect(self, obj)
            end
        elseif typeof(obj) == "Instance" and obj:IsA("TextBox") then
            if obj:GetAttribute("InputFx") then
                applyInputEffect(self, obj)
            end
        end
    end
end

function KeyInterface:_bindEvents()
    local config = self._config or {}
    local discordLink = config.DiscordLink or "https://discord.gg/ddxY6P3Nmp"
    
    local notify = config.notify or function(title, desc, dur, status)
        Interface.Sonner.notify(title, desc, dur, status)
    end

    -- Exit Button
    self:_track(self.UI["ExitButton"].MouseButton1Click:Connect(function()
        if config.OnClose then
            pcall(config.OnClose)
        end
        self:Destroy()
    end))

    -- Get Key Button
    self:_track(self.UI["GetKeyButton"].MouseButton1Click:Connect(function()
        if config.OnGetKey then
            local success, result = pcall(config.OnGetKey)
            if success then
                if typeof(result) == "string" then
                    self.UI["KeyInputBox"].Text = result
                    if setclipboard then
                        pcall(setclipboard, result)
                    end
                    notify("Key Link Copied", "Open the link in a browser to get your key!", 3, "info")
                elseif typeof(result) == "table" then
                    if result.success then
                        if result.url then
                            self.UI["KeyInputBox"].Text = result.url
                            if setclipboard then
                                pcall(setclipboard, result.url)
                            end
                        end
                        notify(result.title or "Key Link Copied", result.message or "Open the link in a browser to get your key!", 3, "info")
                    else
                        notify("Failed to Copy Link", result.error or "Please join via the Premium button!", 3, "error")
                    end
                else
                    notify("Failed to Copy Link", "Please join via the Premium button!", 3, "error")
                end
            else
                notify("Error", tostring(result), 3, "error")
            end
        else
            notify("Auth Error", "Authentication system is not available.", 3, "error")
        end
    end))

    -- Check Key Button
    self:_track(self.UI["CheckKeyButton"].MouseButton1Click:Connect(function()
        local inputKey = self.UI["KeyInputBox"].Text
        if inputKey == "" then
            notify("No Key", "Please enter a key first!", 3, "warning")
            return
        end
        notify("Checking Key", "Verifying your key...", 3, "searching")
        
        if config.OnCheckKey then
            task.spawn(function()
                local success, result = pcall(config.OnCheckKey, inputKey)
                if success then
                    if typeof(result) == "table" then
                        if result.success then
                            notify("Valid Key!", result.message or "Access granted — welcome to Soulfire.", 2, "success")
                            task.delay(2, function() self:Destroy() end)
                        else
                            notify("Invalid Key", result.error or "The key you entered is not valid.", 3, "error")
                            self.UI["KeyInputBox"].Text = ""
                        end
                    elseif typeof(result) == "boolean" then
                        if result then
                            notify("Valid Key!", "Access granted — welcome to Soulfire.", 2, "success")
                            task.delay(2, function() self:Destroy() end)
                        else
                            notify("Invalid Key", "The key you entered is not valid.", 3, "error")
                            self.UI["KeyInputBox"].Text = ""
                        end
                    else
                        notify("Invalid Key", "The key you entered is not valid.", 3, "error")
                        self.UI["KeyInputBox"].Text = ""
                    end
                else
                    notify("Error", tostring(result), 3, "error")
                    self.UI["KeyInputBox"].Text = ""
                end
            end)
        else
            notify("Auth Error", "Authentication system is not available.", 3, "error")
            self.UI["KeyInputBox"].Text = ""
        end
    end))

    -- Buy Button
    self:_track(self.UI["BuyButton"].MouseButton1Click:Connect(function()
        if setclipboard then
            pcall(setclipboard, discordLink)
            notify("Link Copied", "Open the link in a browser to upgrade!", 3, "gold")
        else
            notify("Failed to Copy Link", "Your executor doesn't support setclipboard.", 3, "error")
        end
        self.UI["KeyInputBox"].Text = discordLink
    end))
end

-- ======================== SONNER NOTIFICATIONS ========================

local Sonner = {
    Wrapper = nil,
    Container = nil,
}
Interface.Sonner = Sonner

local SonnerPalette = {
    bg = Color3.fromRGB(37, 33, 96),
    stroke = Color3.fromRGB(86, 79, 171),
    title = Color3.fromRGB(136, 126, 255),
    desc = Color3.fromRGB(201, 201, 255),
    success = Color3.fromRGB(100, 200, 100),
    error = Color3.fromRGB(200, 100, 100),
    warning = Color3.fromRGB(255, 255, 75),
    info = Color3.fromRGB(100, 150, 255),
    searching = Color3.fromRGB(100, 150, 255),
    gold = Color3.fromRGB(241, 192, 68),
}

local STATUS_COLORS = {
    success = SonnerPalette.success,
    error = SonnerPalette.error,
    warning = SonnerPalette.warning,
    info = SonnerPalette.info,
    searching = SonnerPalette.searching,
    normal = SonnerPalette.stroke,
    gold = SonnerPalette.gold,
}

local STATUS_ICONS = {
    success = "circle-check",
    error = "circle-alert",
    warning = "triangle-alert",
    info = "info",
    searching = "loader-circle",
    normal = "bell",
    gold = "crown",
}

local activeNotifications = {}

local function updatePositions()
    local yOffset = -20
    for i = #activeNotifications, 1, -1 do
        local card = activeNotifications[i]
        local height = card.Size.Y.Offset
        local targetPos = UDim2.new(1, -20, 1, yOffset - height)

        TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = targetPos
        }):Play()

        yOffset = yOffset - height - 10
    end
end

function Sonner.init()
    if Sonner.Wrapper then return end
    Sonner.Wrapper = Interface.New("ScreenGui", {
        Name = "Sonner",
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100000000,
        Parent = gethui(),
    })

    Sonner.Container = Interface.New("Frame", {
        Name = "Container",
        Size = UDim2.new(0, 300, 1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Parent = Sonner.Wrapper,
    })
end

Sonner.Init = Sonner.init

function Sonner.notify(title: string, description: string?, duration: number?, status: string?, icon: string?)
    Sonner.init()

    status = status or "normal"
    local statusColor = STATUS_COLORS[status] or SonnerPalette.stroke
    local iconName = icon or STATUS_ICONS[status] or "bell"
    duration = duration or 3

    local height = description and 64 or 40

    local card = Interface.New("CanvasGroup", {
        Name = "Notification",
        Size = UDim2.new(0, 300, 0, height),
        Position = UDim2.new(1, 320, 1, -20),
        BackgroundColor3 = SonnerPalette.bg,
        BorderSizePixel = 0,
        GroupTransparency = 1,

        ["UICorner"] = {
            CornerRadius = UDim.new(0, 8),
        },
        ["UIStroke"] = {
            Thickness = 2,
            Color = statusColor,
        }
    })

    local uiScale = Interface.New("UIScale", { Scale = 0.8 })
    uiScale.Parent = card

    -- Icon
    local resolvedIcon = Interface.GetCustomIcon(iconName)
    local iconImage = resolvedIcon and resolvedIcon.Url or ""
    local iconRectOffset = resolvedIcon and resolvedIcon.ImageRectOffset or Vector2.zero
    local iconRectSize = resolvedIcon and resolvedIcon.ImageRectSize or Vector2.zero

    local iconLabel = Interface.New("ImageLabel", {
        Name = "Icon",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(0, 12, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Image = iconImage,
        ImageRectOffset = iconRectOffset,
        ImageRectSize = iconRectSize,
        BackgroundTransparency = 1,
        Parent = card,
    })

    if status == "searching" then
        task.spawn(function()
            local spinTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
            local spinTween = TweenService:Create(iconLabel, spinTweenInfo, { Rotation = 360 })
            spinTween:Play()
            card.Destroying:Connect(function()
                spinTween:Cancel()
            end)
        end)
    end

    if description then
        -- Title
        Interface.New("TextLabel", {
            Name = "Title",
            Size = UDim2.new(1, -52, 0, 18),
            Position = UDim2.new(0, 44, 0.2, 0),
            Text = title,
            TextSize = 14,
            TextColor3 = SonnerPalette.title,
            FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })
        -- Description
        Interface.New("TextLabel", {
            Name = "Description",
            Size = UDim2.new(1, -52, 0, 28),
            Position = UDim2.new(0, 44, 0.52, 0),
            Text = description,
            TextSize = 12,
            TextColor3 = SonnerPalette.desc,
            FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Parent = card,
        })
    else
        -- Just Title centered vertically
        Interface.New("TextLabel", {
            Name = "Title",
            Size = UDim2.new(1, -52, 1, 0),
            Position = UDim2.new(0, 44, 0, 0),
            Text = title,
            TextSize = 13,
            TextColor3 = Color3.new(1, 1, 1),
            FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = true,
            Parent = card,
        })
    end

    card.Parent = Sonner.Container
    table.insert(activeNotifications, card)

    -- Animate entry
    local entryInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(card, entryInfo, { GroupTransparency = 0 }):Play()
    TweenService:Create(uiScale, entryInfo, { Scale = 1 }):Play()

    updatePositions()

    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true

        local idx = table.find(activeNotifications, card)
        if idx then
            table.remove(activeNotifications, idx)
        end
        updatePositions()

        local exitInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        local t1 = TweenService:Create(card, exitInfo, { GroupTransparency = 1, Position = card.Position + UDim2.new(0, 320, 0, 0) })
        local t2 = TweenService:Create(uiScale, exitInfo, { Scale = 0.8 })
        t1:Play()
        t2:Play()
        t1.Completed:Connect(function()
            card:Destroy()
        end)
    end

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dismiss()
        end
    end)

    task.delay(duration, dismiss)
end

function Sonner.success(text, duration)
    Sonner.notify(text, nil, duration, "success")
end

function Sonner.error(text, duration)
    Sonner.notify(text, nil, duration, "error")
end

function Sonner.warning(text, duration)
    Sonner.notify(text, nil, duration, "warning")
end

function Sonner.info(text, duration)
    Sonner.notify(text, nil, duration, "info")
end

function Sonner.toast(text, duration)
    Sonner.notify(text, nil, duration, "normal")
end

return Interface
