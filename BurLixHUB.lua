-- BurLixHUB.lua
-- A standard Roblox LocalScript for testing character physics and UI layouts in Roblox Studio.
-- Place this script in StarterPlayer -> StarterPlayerScripts or StarterGui.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Compatibility polyfill for environments without math.round (standard Lua 5.1)
if not math.round then
    math.round = function(val)
        return math.floor(val + 0.5)
    end
end

-- Robust LocalPlayer lookup
local player = Players.LocalPlayer
if not player then
    while not Players.LocalPlayer do
        task.wait()
    end
    player = Players.LocalPlayer
end

-- Safely get PlayerGui and CoreGui references
local playerGui = player:WaitForChild("PlayerGui")
local coreGui = nil
pcall(function()
    coreGui = game:GetService("CoreGui")
end)

-- Double run check (Safe destruction of old instances using loop cleanup and pcall locks)
pcall(function()
    if playerGui then
        for _, child in ipairs(playerGui:GetChildren()) do
            if child.Name == "BurLixGUI" then
                child:Destroy()
            end
        end
    end
end)

pcall(function()
    if coreGui then
        for _, child in ipairs(coreGui:GetChildren()) do
            if child.Name == "BurLixGUI" then
                child:Destroy()
            end
        end
    end
end)

-- Determine safe parenting target (Check if writing to CoreGui is allowed, fallback to PlayerGui)
local targetParent = playerGui
if coreGui then
    local success = pcall(function()
        local test = Instance.new("ScreenGui")
        test.Name = "TestBurLix"
        test.Parent = coreGui
        test:Destroy()
    end)
    if success then
        targetParent = coreGui
    end
end

-- Helper function to convert Color3 to hex string
local function colorToHex(color)
    local r = math.round(color.R * 255)
    local g = math.round(color.G * 255)
    local b = math.round(color.B * 255)
    return string.format("#%02X%02X%02X", r, g, b)
end

-- Helper function to convert hex string to Color3
local function hexToColor(hex)
    hex = hex:gsub("#", "")
    if #hex == 6 then
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        if r and g and b then
            return Color3.fromRGB(r, g, b)
        end
    end
    return nil
end

-- Fallback Settings
local currentWalkSpeed = 16
local isJumpPower = true
local currentJumpValue = 50
local minJump = 0
local maxJump = 250

local humanoid = nil
local character = nil

-- Tab and Settings State variables
local lastActiveTab = "Player"
local activeTabName = "Player"
local islandVisible = true
local fpsVisible = true
local pingVisible = true
local menuKeybind = Enum.KeyCode.P
local islandFrame = nil
local islandFPS = nil
local islandPing = nil
local resizing = false
local resizeDragInput = nil
local resizeStartPos = nil
local resizeStartSize = nil

-- Visuals State variables
local highlightEnabled = false
local bordersEnabled = false
local namesEnabled = false
local boxesEnabled = false

-- Visuals Customization Settings
local highlightColor = Color3.fromRGB(80, 80, 250)
local highlightTransparency = 0.5
local highlightOutlineTransparency = 0.5

local borderColor = Color3.fromRGB(255, 255, 255)
local borderTransparency = 0

local nameColor = Color3.fromRGB(255, 255, 255)
local nameSize = 14
local nameStrokeThickness = 1.5

local boxColor = Color3.fromRGB(80, 80, 250)
local boxThickness = 1.5
local boxTransparency = 0

-- Connections list to disconnect on unload to prevent leaks
local connections = {}

-- Themes Configuration
local currentTheme = "Dark"
local themes = {
    Dark = {
        Background = Color3.fromRGB(30, 30, 35),
        Header = Color3.fromRGB(40, 40, 45),
        Accent = Color3.fromRGB(80, 80, 250),
        Sidebar = Color3.fromRGB(35, 35, 40),
        Card = Color3.fromRGB(45, 45, 50),
        Text = Color3.fromRGB(240, 240, 245)
    },
    Purple = {
        Background = Color3.fromRGB(25, 20, 35),
        Header = Color3.fromRGB(35, 25, 50),
        Accent = Color3.fromRGB(160, 80, 250),
        Sidebar = Color3.fromRGB(30, 25, 40),
        Card = Color3.fromRGB(40, 35, 55),
        Text = Color3.fromRGB(245, 240, 250)
    },
    Aqua = {
        Background = Color3.fromRGB(15, 25, 30),
        Header = Color3.fromRGB(20, 35, 45),
        Accent = Color3.fromRGB(0, 200, 200),
        Sidebar = Color3.fromRGB(18, 30, 38),
        Card = Color3.fromRGB(25, 45, 55),
        Text = Color3.fromRGB(230, 245, 245)
    },
    Sakura = {
        Background = Color3.fromRGB(35, 25, 30),
        Header = Color3.fromRGB(45, 30, 40),
        Accent = Color3.fromRGB(250, 100, 150),
        Sidebar = Color3.fromRGB(40, 28, 35),
        Card = Color3.fromRGB(55, 38, 48),
        Text = Color3.fromRGB(255, 240, 245)
    },
    Cyberpunk = {
        Background = Color3.fromRGB(15, 12, 22),
        Header = Color3.fromRGB(22, 18, 32),
        Accent = Color3.fromRGB(255, 0, 128),
        Sidebar = Color3.fromRGB(18, 15, 26),
        Card = Color3.fromRGB(30, 22, 42),
        Text = Color3.fromRGB(0, 255, 255)
    },
    Forest = {
        Background = Color3.fromRGB(15, 22, 18),
        Header = Color3.fromRGB(20, 32, 25),
        Accent = Color3.fromRGB(50, 200, 120),
        Sidebar = Color3.fromRGB(18, 26, 21),
        Card = Color3.fromRGB(25, 42, 32),
        Text = Color3.fromRGB(230, 245, 235)
    },
    Nordic = {
        Background = Color3.fromRGB(32, 36, 44),
        Header = Color3.fromRGB(40, 44, 52),
        Accent = Color3.fromRGB(120, 180, 240),
        Sidebar = Color3.fromRGB(36, 40, 48),
        Card = Color3.fromRGB(48, 54, 66),
        Text = Color3.fromRGB(240, 244, 248)
    },
    Sunset = {
        Background = Color3.fromRGB(28, 16, 16),
        Header = Color3.fromRGB(36, 20, 20),
        Accent = Color3.fromRGB(240, 110, 50),
        Sidebar = Color3.fromRGB(32, 18, 18),
        Card = Color3.fromRGB(46, 26, 26),
        Text = Color3.fromRGB(255, 235, 230)
    }
}

local themeElements = {
    Background = {},
    Header = {},
    Accent = {},
    Sidebar = {},
    Card = {},
    Text = {}
}
local toggleUpdaters = {}

local function registerThemeElement(element, category)
    if themeElements[category] then
        table.insert(themeElements[category], element)
    end
    local colors = themes[currentTheme]
    if not colors then return end
    pcall(function()
        if category == "Text" then
            element.TextColor3 = colors.Text
        elseif category == "Background" then
            element.BackgroundColor3 = colors.Background
        elseif category == "Header" then
            element.BackgroundColor3 = colors.Header
        elseif category == "Accent" then
            if element:IsA("TextLabel") or element:IsA("TextBox") or element:IsA("TextButton") then
                element.TextColor3 = colors.Accent
            else
                element.BackgroundColor3 = colors.Accent
            end
        elseif category == "Sidebar" then
            element.BackgroundColor3 = colors.Sidebar
        elseif category == "Card" then
            element.BackgroundColor3 = colors.Card
        end
    end)
end

local function updateTabColors()
    local colors = themes[currentTheme]
    if not colors then return end
    for name, data in pairs(tabs) do
        if name == activeTabName then
            data.Button.BackgroundColor3 = colors.Card
        else
            data.Button.BackgroundColor3 = colors.Sidebar
        end
        data.Button.TextColor3 = colors.Text
    end
    if settingsButton then
        settingsButton.BackgroundColor3 = activeTabName == "Settings" and colors.Accent or colors.Header
    end
end

local function applyTheme(themeName)
    currentTheme = themeName
    local colors = themes[themeName]
    if not colors then return end
    
    for _, elem in ipairs(themeElements.Background) do
        pcall(function() elem.BackgroundColor3 = colors.Background end)
    end
    for _, elem in ipairs(themeElements.Header) do
        pcall(function() elem.BackgroundColor3 = colors.Header end)
    end
    for _, elem in ipairs(themeElements.Accent) do
        pcall(function() elem.BackgroundColor3 = colors.Accent end)
    end
    for _, elem in ipairs(themeElements.Sidebar) do
        pcall(function() elem.BackgroundColor3 = colors.Sidebar end)
    end
    for _, elem in ipairs(themeElements.Card) do
        pcall(function() elem.BackgroundColor3 = colors.Card end)
    end
    for _, elem in ipairs(themeElements.Text) do
        pcall(function() elem.TextColor3 = colors.Text end)
    end
    
    for _, updater in ipairs(toggleUpdaters) do
        pcall(updater)
    end
    
    pcall(updateTabColors)
end

-- Create GUI Elements early to guarantee UI is loaded
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BurLixGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = targetParent

-- Main Frame (Wider to accommodate left tab sidebar)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 600, 0, 420)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = false
mainFrame.Parent = screenGui
registerThemeElement(mainFrame, "Background")

-- UI Corner for Main Frame (Less rounded)
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 4)
mainCorner.Parent = mainFrame

local resizeGrip = Instance.new("TextButton")
resizeGrip.Name = "ResizeGrip"
resizeGrip.Size = UDim2.new(0, 16, 0, 16)
resizeGrip.Position = UDim2.new(1, -16, 1, -16)
resizeGrip.BackgroundTransparency = 1
resizeGrip.Text = "◢"
resizeGrip.TextColor3 = Color3.fromRGB(150, 150, 155)
resizeGrip.TextSize = 12
resizeGrip.Font = Enum.Font.SourceSansBold
resizeGrip.Active = true
resizeGrip.Parent = mainFrame
registerThemeElement(resizeGrip, "Text")

-- Resize Grip Hover effect
table.insert(connections, resizeGrip.MouseEnter:Connect(function()
    local colors = themes[currentTheme]
    if colors then
        TweenService:Create(resizeGrip, TweenInfo.new(0.2), {TextColor3 = colors.Accent}):Play()
    end
end))
table.insert(connections, resizeGrip.MouseLeave:Connect(function()
    local colors = themes[currentTheme]
    if colors then
        TweenService:Create(resizeGrip, TweenInfo.new(0.2), {TextColor3 = colors.Text}):Play()
    end
end))

local function updateResize(input)
    local delta = input.Position - resizeStartPos
    local newWidth = math.clamp(resizeStartSize.X + delta.X, 450, 800)
    local newHeight = math.clamp(resizeStartSize.Y + delta.Y, 320, 600)
    mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
end

table.insert(connections, resizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStartPos = input.Position
        resizeStartSize = mainFrame.AbsoluteSize
        
        local changedConn
        changedConn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizing = false
                if changedConn then
                    changedConn:Disconnect()
                end
            end
        end)
    end
end))

table.insert(connections, resizeGrip.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        resizeDragInput = input
    end
end))

local function toggleUI()
    mainFrame.Visible = not mainFrame.Visible
end

-- ==================== TOP STATS ISLAND ====================

islandFrame = Instance.new("Frame")
islandFrame.Name = "IslandFrame"
islandFrame.Size = UDim2.new(0, 380, 0, 35)
islandFrame.Position = UDim2.new(0.5, -190, 0, 15)
islandFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
islandFrame.BorderSizePixel = 0
islandFrame.Active = true
islandFrame.Draggable = true
islandFrame.Parent = screenGui
registerThemeElement(islandFrame, "Sidebar")

local islandCorner = Instance.new("UICorner")
islandCorner.CornerRadius = UDim.new(0, 4)
islandCorner.Parent = islandFrame

local islandLayout = Instance.new("UIListLayout")
islandLayout.FillDirection = Enum.FillDirection.Horizontal
islandLayout.VerticalAlignment = Enum.VerticalAlignment.Center
islandLayout.SortOrder = Enum.SortOrder.LayoutOrder
islandLayout.Padding = UDim.new(0, 10)
islandLayout.Parent = islandFrame

local islandPadding = Instance.new("UIPadding")
islandPadding.PaddingLeft = UDim.new(0, 10)
islandPadding.PaddingRight = UDim.new(0, 10)
islandPadding.Parent = islandFrame

-- Helper function to create labels for the island
local function createIslandLabel(text, sizeX, layoutOrder, isAccent)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, sizeX, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.TextSize = 12
    label.Font = Enum.Font.SourceSansBold
    label.LayoutOrder = layoutOrder
    label.Parent = islandFrame
    registerThemeElement(label, isAccent and "Accent" or "Text")
    return label
end

local islandTitle = createIslandLabel("BurLix HUB", 65, 1, true)

-- Vertical Separator on Island
local islandSeparator = Instance.new("Frame")
islandSeparator.Name = "Separator"
islandSeparator.Size = UDim2.new(0, 1, 0, 18)
islandSeparator.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
islandSeparator.BorderSizePixel = 0
islandSeparator.LayoutOrder = 2
islandSeparator.Parent = islandFrame
registerThemeElement(islandSeparator, "Header")

local islandUser = createIslandLabel(player.DisplayName or player.Name or "Player", 80, 3)
islandUser.TextTruncate = Enum.TextTruncate.AtEnd

islandFPS = createIslandLabel("FPS: --", 50, 4)
islandPing = createIslandLabel("Ping: --", 60, 5)

-- Set initial visibility from state
islandFrame.Visible = islandVisible
islandFPS.Visible = fpsVisible
islandPing.Visible = pingVisible

-- Toggle Button on Island
local islandToggle = Instance.new("TextButton")
islandToggle.Size = UDim2.new(0, 60, 0, 25)
islandToggle.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
islandToggle.Text = "Toggle"
islandToggle.TextColor3 = Color3.fromRGB(240, 240, 245)
islandToggle.TextSize = 11
islandToggle.Font = Enum.Font.SourceSansBold
islandToggle.LayoutOrder = 6
islandToggle.Parent = islandFrame
registerThemeElement(islandToggle, "Card")
registerThemeElement(islandToggle, "Text")

local toggleCornerBtn = Instance.new("UICorner")
toggleCornerBtn.CornerRadius = UDim.new(0, 3)
toggleCornerBtn.Parent = islandToggle

table.insert(connections, islandToggle.MouseButton1Click:Connect(toggleUI))

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 45)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
registerThemeElement(titleBar, "Header")

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 4)
titleCorner.Parent = titleBar

-- Title Text
local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Size = UDim2.new(1, -60, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "BurLix HUB v1.7.0"
titleText.TextColor3 = Color3.fromRGB(240, 240, 245)
titleText.TextSize = 18
titleText.Font = Enum.Font.SourceSansBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar
registerThemeElement(titleText, "Text")

-- Title Bar Separator Line
local titleSeparator = Instance.new("Frame")
titleSeparator.Name = "Separator"
titleSeparator.Size = UDim2.new(1, 0, 0, 1)
titleSeparator.Position = UDim2.new(0, 0, 0, 44)
titleSeparator.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
titleSeparator.BorderSizePixel = 0
titleSeparator.Parent = titleBar
registerThemeElement(titleSeparator, "Header")

-- Settings Button (⚙) to open menu settings
local settingsButton = Instance.new("TextButton")
settingsButton.Name = "SettingsButton"
settingsButton.Size = UDim2.new(0, 24, 0, 24)
settingsButton.Position = UDim2.new(1, -64, 0.5, -12)
settingsButton.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
settingsButton.Text = "⚙"
settingsButton.TextColor3 = Color3.fromRGB(240, 240, 245)
settingsButton.TextSize = 14
settingsButton.Font = Enum.Font.SourceSansBold
settingsButton.Parent = titleBar
registerThemeElement(settingsButton, "Header")

local settingsCorner = Instance.new("UICorner")
settingsCorner.CornerRadius = UDim.new(0, 3)
settingsCorner.Parent = settingsButton

-- Settings Button Hover Styles
settingsButton.MouseEnter:Connect(function()
    if activeTabName ~= "Settings" then
        local colors = themes[currentTheme]
        local hoverColor = colors and Color3.fromRGB(
            math.clamp(colors.Header.R * 255 + 20, 0, 255),
            math.clamp(colors.Header.G * 255 + 20, 0, 255),
            math.clamp(colors.Header.B * 255 + 20, 0, 255)
        ) or Color3.fromRGB(70, 70, 75)
        TweenService:Create(settingsButton, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
    end
end)
settingsButton.MouseLeave:Connect(function()
    if activeTabName ~= "Settings" then
        local colors = themes[currentTheme]
        TweenService:Create(settingsButton, TweenInfo.new(0.2), {BackgroundColor3 = colors and colors.Header or Color3.fromRGB(50, 50, 55)}):Play()
    end
end)

-- Close Button (X) to completely close the script
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 24, 0, 24)
closeButton.Position = UDim2.new(1, -34, 0.5, -12)
closeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(240, 240, 245)
closeButton.TextSize = 12
closeButton.Font = Enum.Font.SourceSansBold
closeButton.Parent = titleBar
registerThemeElement(closeButton, "Header")

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 3)
closeCorner.Parent = closeButton

-- Settings popup was removed in favor of a dedicated hidden Settings Tab

-- Close Button Hover/Click Styles
closeButton.MouseEnter:Connect(function()
    closeButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
end)
closeButton.MouseLeave:Connect(function()
    local colors = themes[currentTheme]
    closeButton.BackgroundColor3 = colors and colors.Header or Color3.fromRGB(50, 50, 55)
end)

-- Navigation Panel (Sidebar)
local navPanel = Instance.new("Frame")
navPanel.Name = "NavigationPanel"
navPanel.Size = UDim2.new(0, 110, 1, -45)
navPanel.Position = UDim2.new(0, 0, 0, 45)
navPanel.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
navPanel.BorderSizePixel = 0
navPanel.Parent = mainFrame
registerThemeElement(navPanel, "Sidebar")

local navCorner = Instance.new("UICorner")
navCorner.CornerRadius = UDim.new(0, 4)
navCorner.Parent = navPanel

-- Left list layout for navigation buttons
local navList = Instance.new("UIListLayout")
navList.Padding = UDim.new(0, 8)
navList.SortOrder = Enum.SortOrder.LayoutOrder
navList.Parent = navPanel

local navPadding = Instance.new("UIPadding")
navPadding.PaddingTop = UDim.new(0, 10)
navPadding.PaddingLeft = UDim.new(0, 8)
navPadding.PaddingRight = UDim.new(0, 8)
navPadding.Parent = navPanel

-- Content Container Panel (Right side)
local contentContainer = Instance.new("Frame")
contentContainer.Name = "ContentContainer"
contentContainer.Size = UDim2.new(1, -110, 1, -45)
contentContainer.Position = UDim2.new(0, 110, 0, 45)
contentContainer.BackgroundTransparency = 1
contentContainer.BorderSizePixel = 0
contentContainer.Parent = mainFrame

-- Tab system logic
local tabs = {}

local function showTab(tabName)
    if tabName ~= "Settings" then
        lastActiveTab = tabName
    end
    activeTabName = tabName
    
    for name, data in pairs(tabs) do
        if name == tabName then
            data.Frame.Visible = true
        else
            data.Frame.Visible = false
        end
    end
    
    pcall(updateTabColors)
end

local function createTab(name, layoutOrder, canvasHeight)
    -- Navigation Button
    local btn = Instance.new("TextButton")
    btn.Name = name .. "TabButton"
    btn.Size = name == "Settings" and UDim2.new(0, 0, 0, 0) or UDim2.new(1, 0, 0, 32)
    btn.Visible = name ~= "Settings"
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(220, 220, 225)
    btn.TextSize = 13
    btn.Font = Enum.Font.SourceSansBold
    btn.LayoutOrder = layoutOrder
    btn.Parent = navPanel

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 3)
    btnCorner.Parent = btn

    -- Hover effect for tab button (only if visible)
    if name ~= "Settings" then
        btn.MouseEnter:Connect(function()
            local colors = themes[currentTheme]
            if colors and btn.BackgroundColor3 ~= colors.Card then
                local hoverColor = Color3.fromRGB(
                    math.clamp(colors.Sidebar.R * 255 + 10, 0, 255),
                    math.clamp(colors.Sidebar.G * 255 + 10, 0, 255),
                    math.clamp(colors.Sidebar.B * 255 + 10, 0, 255)
                )
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            local colors = themes[currentTheme]
            if colors and btn.BackgroundColor3 ~= colors.Card then
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = colors.Sidebar}):Play()
            end
        end)
    end

    -- Content Frame
    local frame = Instance.new("ScrollingFrame")
    frame.Name = name .. "TabFrame"
    frame.Size = UDim2.new(1, -20, 1, -20)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4
    frame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 110)
    frame.CanvasSize = UDim2.new(0, 0, 0, canvasHeight or 400)
    frame.Visible = false
    frame.Parent = contentContainer

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = frame

    tabs[name] = {Button = btn, Frame = frame}

    btn.MouseButton1Click:Connect(function()
        showTab(name)
    end)

    registerThemeElement(btn, "Text")

    return frame
end

-- Helper Function to Create Row Frames inside Tab Frames
local function createRow(tabFrame, name, height, layoutOrder)
    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, height)
    row.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    row.BorderSizePixel = 0
    row.LayoutOrder = layoutOrder
    row.Parent = tabFrame

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 3)
    rowCorner.Parent = row

    registerThemeElement(row, "Card")

    return row
end

-- Helper Function to Create Sliders
local function createSlider(tabFrame, name, minVal, maxVal, defaultVal, layoutOrder, onChange)
    local row = createRow(tabFrame, name .. "Row", 70, layoutOrder)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 25)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. tostring(defaultVal)
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.TextSize = 14
    label.Font = Enum.Font.SourceSansBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    
    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -20, 0, 8)
    sliderBar.Position = UDim2.new(0, 10, 0, 40)
    sliderBar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = row
    
    local sliderBarCorner = Instance.new("UICorner")
    sliderBarCorner.CornerRadius = UDim.new(0, 3)
    sliderBarCorner.Parent = sliderBar
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 250)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar
    
    local sliderFillCorner = Instance.new("UICorner")
    sliderFillCorner.CornerRadius = UDim.new(0, 3)
    sliderFillCorner.Parent = sliderFill
    
    local sliderButton = Instance.new("Frame")
    sliderButton.Size = UDim2.new(0, 16, 0, 16)
    sliderButton.Position = UDim2.new(0, -8, 0.5, -8)
    sliderButton.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
    sliderButton.BorderSizePixel = 0
    sliderButton.Parent = sliderBar
    
    local sliderBtnCorner = Instance.new("UICorner")
    sliderBtnCorner.CornerRadius = UDim.new(1, 0)
    sliderBtnCorner.Parent = sliderButton
    
    local function updateSlider(percentage)
        percentage = math.clamp(percentage, 0, 1)
        sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        sliderButton.Position = UDim2.new(percentage, -8, 0.5, -8)
        
        local val = math.round(minVal + (maxVal - minVal) * percentage)
        label.Text = name .. ": " .. tostring(val)
        onChange(val)
    end
    
    local initialPercent = (defaultVal - minVal) / (maxVal - minVal)
    updateSlider(initialPercent)
    
    local active = false
    
    local function processInput(input)
        local barSize = sliderBar.AbsoluteSize.X
        local barPos = sliderBar.AbsolutePosition.X
        local mousePos = input.Position.X
        local percentage = (mousePos - barPos) / barSize
        updateSlider(percentage)
    end
    
    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            active = true
            processInput(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            processInput(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            active = false
        end
    end)

    registerThemeElement(label, "Text")
    registerThemeElement(sliderBar, "Sidebar")
    registerThemeElement(sliderFill, "Accent")

    return row, updateSlider
end

-- Helper Function to Create Toggles
local function createToggle(tabFrame, name, defaultVal, layoutOrder, onChange, onRightClick)
    -- Create row as TextButton to capture clicks across the whole row area
    local row = Instance.new("TextButton")
    row.Name = name .. "Row"
    row.Size = UDim2.new(1, 0, 0, 45)
    row.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    row.BorderSizePixel = 0
    row.LayoutOrder = layoutOrder
    row.Text = ""
    row.AutoButtonColor = false -- Disable default dark overlay on click to keep custom theme
    row.Parent = tabFrame
    
    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 3)
    rowCorner.Parent = row
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.TextSize = 14
    label.Font = Enum.Font.SourceSansBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    
    -- Make toggleButton a Frame, so clicks on it fall through to the row TextButton
    local toggleButton = Instance.new("Frame")
    toggleButton.Size = UDim2.new(0, 40, 0, 20)
    toggleButton.Position = UDim2.new(1, -50, 0.5, -10)
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = row
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 10)
    toggleCorner.Parent = toggleButton
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultVal and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
    knob.BorderSizePixel = 0
    knob.Parent = toggleButton
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobKnobCorner = knobCorner -- local copy
    knobCorner.Parent = knob
    
    local enabled = defaultVal
    
    local function updateToggleColor()
        local colors = themes[currentTheme]
        if colors then
            toggleButton.BackgroundColor3 = enabled and colors.Accent or colors.Sidebar
        end
    end
    
    table.insert(toggleUpdaters, updateToggleColor)
    updateToggleColor()
    
    -- Click logic for the entire row (MouseButton1Click for toggle)
    table.insert(connections, row.MouseButton1Click:Connect(function()
        enabled = not enabled
        local colors = themes[currentTheme]
        local targetColor = colors and (enabled and colors.Accent or colors.Sidebar) or (enabled and Color3.fromRGB(80, 80, 250) or Color3.fromRGB(35, 35, 40))
        local targetPos = enabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        
        TweenService:Create(toggleButton, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
        
        onChange(enabled)
    end))
    
    -- Hover effect for the entire row (darken slightly on hover)
    table.insert(connections, row.MouseEnter:Connect(function()
        local colors = themes[currentTheme]
        if colors then
            local hoverColor = Color3.fromRGB(
                math.clamp(colors.Card.R * 255 - 7, 0, 255),
                math.clamp(colors.Card.G * 255 - 7, 0, 255),
                math.clamp(colors.Card.B * 255 - 7, 0, 255)
            )
            TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
        end
    end))
    
    table.insert(connections, row.MouseLeave:Connect(function()
        local colors = themes[currentTheme]
        if colors then
            TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = colors.Card}):Play()
        end
    end))
    
    -- Right click logic for the entire row (MouseButton2Click to open settings)
    if onRightClick then
        table.insert(connections, row.MouseButton2Click:Connect(function()
            onRightClick()
        end))
    end
    
    registerThemeElement(row, "Card")
    registerThemeElement(label, "Text")
    return row
end

-- Helper function to toggle settings panel with smooth Size animation
local function toggleSettingsPanel(panel, targetHeight)
    local isOpening = not panel.Visible or panel.Size.Y.Offset == 0
    
    if isOpening then
        panel.Visible = true
        panel.Size = UDim2.new(1, 0, 0, 0)
        local tween = TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, targetHeight)
        })
        tween:Play()
    else
        local tween = TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, 0)
        })
        tween:Play()
        local conn
        conn = tween.Completed:Connect(function()
            if panel.Size.Y.Offset == 0 then
                panel.Visible = false
            end
            conn:Disconnect()
        end)
    end
end

-- Helper Function to Create Settings Panel with Presets, HEX Input and custom sliders
local function createSettingsPanel(tabFrame, layoutOrder, defaultColor, onColorChange, customSliders)
    local rowHeight = 24
    local panelHeight = (1 + #customSliders) * rowHeight + 10
    
    local panel = Instance.new("Frame")
    panel.Name = "SettingsPanel"
    panel.Size = UDim2.new(1, 0, 0, 0) -- Starts at 0 height for animation
    panel.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    panel.BorderSizePixel = 0
    panel.LayoutOrder = layoutOrder
    panel.Visible = false
    panel.ClipsDescendants = true -- Crucial for smooth size animation
    panel.Parent = tabFrame
    registerThemeElement(panel, "Sidebar")
    
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 3)
    panelCorner.Parent = panel
    
    local panelPadding = Instance.new("UIPadding")
    panelPadding.PaddingTop = UDim.new(0, 5)
    panelPadding.PaddingBottom = UDim.new(0, 5)
    panelPadding.PaddingLeft = UDim.new(0, 10)
    panelPadding.PaddingRight = UDim.new(0, 10)
    panelPadding.Parent = panel
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = panel
    
    -- Color Row (Presets + HEX TextBox)
    local colorRow = Instance.new("Frame")
    colorRow.Size = UDim2.new(1, 0, 0, rowHeight)
    colorRow.BackgroundTransparency = 1
    colorRow.LayoutOrder = 1
    colorRow.Parent = panel
    
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0, 45, 1, 0)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "Color:"
    colorLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
    colorLabel.TextSize = 11
    colorLabel.Font = Enum.Font.SourceSansBold
    colorLabel.TextXAlignment = Enum.TextXAlignment.Left
    colorLabel.Parent = colorRow
    registerThemeElement(colorLabel, "Text")
    
    -- HEX TextBox
    local hexInput = Instance.new("TextBox")
    hexInput.Size = UDim2.new(0, 65, 0, 18)
    hexInput.Position = UDim2.new(1, -65, 0.5, -9)
    hexInput.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    hexInput.BorderSizePixel = 0
    hexInput.Text = colorToHex(defaultColor)
    hexInput.TextColor3 = Color3.fromRGB(220, 220, 225)
    hexInput.TextSize = 10
    hexInput.Font = Enum.Font.Code
    hexInput.ClearTextOnFocus = false
    hexInput.Parent = colorRow
    registerThemeElement(hexInput, "Background")
    registerThemeElement(hexInput, "Text")
    
    local hexCorner = Instance.new("UICorner")
    hexCorner.CornerRadius = UDim.new(0, 2)
    hexCorner.Parent = hexInput
    
    local hexStroke = Instance.new("UIStroke")
    hexStroke.Thickness = 1
    hexStroke.Color = Color3.fromRGB(50, 50, 55)
    hexStroke.Parent = hexInput
    
    -- Presets Container
    local presetsContainer = Instance.new("Frame")
    presetsContainer.Size = UDim2.new(1, -120, 1, 0)
    presetsContainer.Position = UDim2.new(0, 45, 0, 0)
    presetsContainer.BackgroundTransparency = 1
    presetsContainer.Parent = colorRow
    
    local presetsLayout = Instance.new("UIListLayout")
    presetsLayout.FillDirection = Enum.FillDirection.Horizontal
    presetsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    presetsLayout.Padding = UDim.new(0, 4)
    presetsLayout.Parent = presetsContainer
    
    local presets = {
        Color3.fromRGB(80, 80, 250),   -- Blue
        Color3.fromRGB(250, 80, 80),   -- Red
        Color3.fromRGB(80, 250, 80),   -- Green
        Color3.fromRGB(250, 250, 80),  -- Yellow
        Color3.fromRGB(255, 255, 255), -- White
        Color3.fromRGB(250, 80, 250),  -- Purple
        Color3.fromRGB(250, 150, 50),  -- Orange
        Color3.fromRGB(80, 250, 250),  -- Cyan
        Color3.fromRGB(250, 120, 170), -- Pink
        Color3.fromRGB(150, 250, 80),  -- Lime
        Color3.fromRGB(0, 0, 0),       -- Black
        Color3.fromRGB(150, 150, 150)  -- Grey
    }
    
    local function selectColor(color, skipHexUpdate)
        onColorChange(color)
        if not skipHexUpdate then
            hexInput.Text = colorToHex(color)
        end
        -- Highlight active preset button
        for _, child in ipairs(presetsContainer:GetChildren()) do
            if child:IsA("TextButton") then
                local stroke = child:FindFirstChild("UIStroke")
                if stroke then
                    local isMatch = (child.BackgroundColor3.R == color.R and child.BackgroundColor3.G == color.G and child.BackgroundColor3.B == color.B)
                    stroke.Color = isMatch and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(35, 35, 40)
                end
            end
        end
    end
    
    for _, color in ipairs(presets) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 12, 0, 12)
        btn.BackgroundColor3 = color
        btn.Text = ""
        btn.Parent = presetsContainer
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(1, 0)
        btnCorner.Parent = btn
        
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.5
        stroke.Color = Color3.fromRGB(35, 35, 40)
        stroke.Parent = btn
        
        table.insert(connections, btn.MouseButton1Click:Connect(function()
            selectColor(color)
        end))
    end
    
    -- Handle HEX input updates
    table.insert(connections, hexInput.FocusLost:Connect(function(enterPressed)
        local inputColor = hexToColor(hexInput.Text)
        if inputColor then
            selectColor(inputColor, true)
            hexStroke.Color = Color3.fromRGB(50, 180, 50) -- Green feedback for success
            task.delay(0.5, function()
                hexStroke.Color = Color3.fromRGB(50, 50, 55)
            end)
        else
            -- Revert to current color on invalid input
            hexInput.Text = hexInput.Text -- triggers redraw of text
            hexStroke.Color = Color3.fromRGB(180, 50, 50) -- Red feedback for error
            task.delay(0.5, function()
                hexStroke.Color = Color3.fromRGB(50, 50, 55)
            end)
        end
    end))
    
    -- Helper to build a compact slider inside the panel
    local function buildCompactSlider(sliderName, minVal, maxVal, defaultVal, onChange, layoutOrder)
        local sliderRow = Instance.new("Frame")
        sliderRow.Size = UDim2.new(1, 0, 0, rowHeight)
        sliderRow.BackgroundTransparency = 1
        sliderRow.LayoutOrder = layoutOrder
        sliderRow.Parent = panel
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 90, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = sliderName .. ": " .. tostring(defaultVal)
        label.TextColor3 = Color3.fromRGB(180, 180, 185)
        label.TextSize = 11
        label.Font = Enum.Font.SourceSansBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = sliderRow
        registerThemeElement(label, "Text")
        
        local sliderBar = Instance.new("Frame")
        sliderBar.Size = UDim2.new(1, -95, 0, 4)
        sliderBar.Position = UDim2.new(0, 95, 0.5, -2)
        sliderBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        sliderBar.BorderSizePixel = 0
        sliderBar.Parent = sliderRow
        registerThemeElement(sliderBar, "Sidebar")
        
        local sliderBarCorner = Instance.new("UICorner")
        sliderBarCorner.CornerRadius = UDim.new(0, 2)
        sliderBarCorner.Parent = sliderBar
        
        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new(0, 0, 1, 0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 250)
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBar
        registerThemeElement(sliderFill, "Accent")
        
        local sliderFillCorner = Instance.new("UICorner")
        sliderFillCorner.CornerRadius = UDim.new(0, 2)
        sliderFillCorner.Parent = sliderFill
        
        local sliderButton = Instance.new("Frame")
        sliderButton.Size = UDim2.new(0, 10, 0, 10)
        sliderButton.Position = UDim2.new(0, -5, 0.5, -5)
        sliderButton.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
        sliderButton.BorderSizePixel = 0
        sliderButton.Parent = sliderBar
        
        local sliderBtnCorner = Instance.new("UICorner")
        sliderBtnCorner.CornerRadius = UDim.new(1, 0)
        sliderBtnCorner.Parent = sliderButton
        
        local function updateVal(percentage)
            percentage = math.clamp(percentage, 0, 1)
            sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
            sliderButton.Position = UDim2.new(percentage, -5, 0.5, -5)
            
            local val
            local range = maxVal - minVal
            if range <= 1 then
                val = math.round((minVal + range * percentage) * 100) / 100
            elseif range <= 10 then
                val = math.round((minVal + range * percentage) * 10) / 10
            else
                val = math.round(minVal + range * percentage)
            end
            
            label.Text = sliderName .. ": " .. tostring(val)
            onChange(val)
        end
        
        local initialPercent = (defaultVal - minVal) / (maxVal - minVal)
        updateVal(initialPercent)
        
        local active = false
        
        local function processInput(input)
            local barSize = sliderBar.AbsoluteSize.X
            local barPos = sliderBar.AbsolutePosition.X
            local mousePos = input.Position.X
            local percentage = (mousePos - barPos) / barSize
            updateVal(percentage)
        end
        
        table.insert(connections, sliderBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                active = true
                processInput(input)
            end
        end))
        
        table.insert(connections, UserInputService.InputChanged:Connect(function(input)
            if active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                processInput(input)
            end
        end))
        
        table.insert(connections, UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                active = false
            end
        end))
    end
    
    -- Add custom sliders
    for idx, sliderConf in ipairs(customSliders) do
        buildCompactSlider(sliderConf.name, sliderConf.min, sliderConf.max, sliderConf.default, sliderConf.onChange, idx + 1)
    end
    
    -- Initial select to match color and outline stroke active state
    selectColor(defaultColor)
    
    return panel, panelHeight
end

-- Create Tabs (Decreased Authors tab canvas height since Reset buttons are removed)
local playerTab = createTab("Player", 1, 200)
local worldTab = createTab("World", 2, 200)
local authorsTab = createTab("Authors", 3, 520)
local visualsTab = createTab("Visuals", 4, 850)
local settingsTab = createTab("Settings", 5, 350)

-- Settings Tab Content
local settingsTitle = Instance.new("TextLabel")
settingsTitle.Name = "SettingsTitle"
settingsTitle.Size = UDim2.new(1, -20, 0, 30)
settingsTitle.Position = UDim2.new(0, 10, 0, 10)
settingsTitle.BackgroundTransparency = 1
settingsTitle.Text = "Menu & Island Settings"
settingsTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
settingsTitle.TextSize = 16
settingsTitle.Font = Enum.Font.SourceSansBold
settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
settingsTitle.LayoutOrder = 0
settingsTitle.Parent = settingsTab
registerThemeElement(settingsTitle, "Text")

local islandVisibleToggle = createToggle(settingsTab, "Show Top Island", true, 1, function(state)
    islandVisible = state
    if islandFrame then
        islandFrame.Visible = state
    end
end)

local fpsVisibleToggle = createToggle(settingsTab, "Show FPS Counter", true, 2, function(state)
    fpsVisible = state
    if islandFPS then
        islandFPS.Visible = state
    end
end)

local pingVisibleToggle = createToggle(settingsTab, "Show Ping Counter", true, 3, function(state)
    pingVisible = state
    if islandPing then
        islandPing.Visible = state
    end
end)

-- Keybind Row
local keybindRow = createRow(settingsTab, "KeybindRow", 45, 4)

local keybindLabel = Instance.new("TextLabel")
keybindLabel.Size = UDim2.new(1, -100, 1, 0)
keybindLabel.Position = UDim2.new(0, 10, 0, 0)
keybindLabel.BackgroundTransparency = 1
keybindLabel.Text = "Menu Toggle Keybind"
keybindLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
keybindLabel.TextSize = 14
keybindLabel.Font = Enum.Font.SourceSansBold
keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
keybindLabel.Parent = keybindRow
registerThemeElement(keybindLabel, "Text")

local keybindInput = Instance.new("TextBox")
keybindInput.Size = UDim2.new(0, 80, 0, 25)
keybindInput.Position = UDim2.new(1, -90, 0.5, -12)
keybindInput.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
keybindInput.BorderSizePixel = 0
keybindInput.Text = "P"
keybindInput.TextColor3 = Color3.fromRGB(240, 240, 245)
keybindInput.TextSize = 12
keybindInput.Font = Enum.Font.Code
keybindInput.ClearTextOnFocus = false
keybindInput.Parent = keybindRow
registerThemeElement(keybindInput, "Background")
registerThemeElement(keybindInput, "Text")

local keybindCorner = Instance.new("UICorner")
keybindCorner.CornerRadius = UDim.new(0, 3)
keybindCorner.Parent = keybindInput

local keybindStroke = Instance.new("UIStroke")
keybindStroke.Thickness = 1
keybindStroke.Color = Color3.fromRGB(55, 55, 60)
keybindStroke.Parent = keybindInput

table.insert(connections, keybindInput.FocusLost:Connect(function(enterPressed)
    local text = keybindInput.Text:upper():gsub("%s+", "")
    if #text == 1 then
        local code = Enum.KeyCode[text]
        if code then
            menuKeybind = code
            keybindInput.Text = text
            keybindStroke.Color = Color3.fromRGB(50, 180, 50)
            task.delay(0.5, function()
                keybindStroke.Color = Color3.fromRGB(55, 55, 60)
            end)
            return
        end
    end
    -- Revert
    for _, code in ipairs(Enum.KeyCode:GetEnumItems()) do
        if code == menuKeybind then
            keybindInput.Text = code.Name
            break
        end
    end
    keybindStroke.Color = Color3.fromRGB(180, 50, 50)
    task.delay(0.5, function()
        keybindStroke.Color = Color3.fromRGB(55, 55, 60)
    end)
end))

-- Theme Selector Row
local themeRow = createRow(settingsTab, "ThemeRow", 45, 5)

local themeLabel = Instance.new("TextLabel")
themeLabel.Size = UDim2.new(1, -280, 1, 0)
themeLabel.Position = UDim2.new(0, 10, 0, 0)
themeLabel.BackgroundTransparency = 1
themeLabel.Text = "Menu Theme"
themeLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
themeLabel.TextSize = 14
themeLabel.Font = Enum.Font.SourceSansBold
themeLabel.TextXAlignment = Enum.TextXAlignment.Left
themeLabel.Parent = themeRow
registerThemeElement(themeLabel, "Text")

local themeContainer = Instance.new("ScrollingFrame")
themeContainer.Size = UDim2.new(0, 260, 0, 28)
themeContainer.Position = UDim2.new(1, -270, 0.5, -14)
themeContainer.BackgroundTransparency = 1
themeContainer.BorderSizePixel = 0
themeContainer.ScrollBarThickness = 2
themeContainer.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 130)
themeContainer.CanvasSize = UDim2.new(0, 8 * 52 + 10, 0, 0)
themeContainer.ScrollingDirection = Enum.ScrollingDirection.X
themeContainer.Parent = themeRow

local themeLayout = Instance.new("UIListLayout")
themeLayout.FillDirection = Enum.FillDirection.Horizontal
themeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
themeLayout.Padding = UDim.new(0, 4)
themeLayout.Parent = themeContainer

local themeNames = {"Dark", "Purple", "Aqua", "Sakura", "Cyberpunk", "Forest", "Nordic", "Sunset"}
for _, name in ipairs(themeNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 48, 0, 20)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(220, 220, 225)
    btn.TextSize = 9
    btn.Font = Enum.Font.SourceSansBold
    btn.Parent = themeContainer
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 3)
    btnCorner.Parent = btn
    
    local function updateBtnStyle()
        local colors = themes[currentTheme]
        if currentTheme == name then
            btn.BackgroundColor3 = colors.Accent
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = colors.Sidebar
            btn.TextColor3 = colors.Text
        end
    end
    
    table.insert(toggleUpdaters, updateBtnStyle)
    
    table.insert(connections, btn.MouseButton1Click:Connect(function()
        applyTheme(name)
    end))
    
    updateBtnStyle()
end

-- DEFAULT TAB SETTINGS
showTab("Player")

-- Sliders reference for async character loading updates
local updateWSSliderUI = nil
local updateJPSliderUI = nil

-- Asynchronously wait for initial character and read default values safely
task.spawn(function()
    character = player.Character or player.CharacterAdded:Wait()
    local hum = character:WaitForChild("Humanoid", 10)
    if hum then
        humanoid = hum
        pcall(function()
            currentWalkSpeed = hum.WalkSpeed
            isJumpPower = hum.UseJumpPower
            currentJumpValue = isJumpPower and hum.JumpPower or hum.JumpHeight
            minJump = 0
            maxJump = isJumpPower and 250 or 150
            
            if updateWSSliderUI then
                updateWSSliderUI((currentWalkSpeed - 16) / (200 - 16))
            end
            if updateJPSliderUI then
                updateJPSliderUI((currentJumpValue - minJump) / (maxJump - minJump))
            end
        end)
    end
end)

-- Re-hook humanoid and re-apply settings on character respawn (preserving slider settings)
table.insert(connections, player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    local hum = newCharacter:WaitForChild("Humanoid", 10)
    if hum then
        humanoid = hum
        task.wait(0.5)
        pcall(function()
            hum.WalkSpeed = currentWalkSpeed
            if hum.UseJumpPower then
                hum.JumpPower = currentJumpValue
            else
                hum.JumpHeight = currentJumpValue
            end
        end)
    end
end))

-- Helper function to apply visuals to a single player character
local function updateCharacterVisuals(targetPlayer, char)
    if not char then return end
    
    -- Outline/Fill highlight handling
    local highlight = char:FindFirstChild("BurLixHighlight")
    if highlightEnabled or bordersEnabled then
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "BurLixHighlight"
            highlight.Parent = char
        end
        highlight.FillColor = highlightColor
        highlight.OutlineColor = borderColor
        highlight.FillTransparency = highlightEnabled and highlightTransparency or 1
        highlight.OutlineTransparency = bordersEnabled and borderTransparency or 1
        
        -- If Highlighting is enabled, but borders is disabled, we still want to show outline with highlightOutlineTransparency
        if highlightEnabled and not bordersEnabled then
            highlight.OutlineTransparency = highlightOutlineTransparency
            highlight.OutlineColor = highlightColor
        end
    else
        if highlight then
            highlight:Destroy()
        end
    end
    
    -- BillboardGui (Boxes) handling (AlwaysOnTop, visible through walls)
    if boxesEnabled then
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 2)
        if hrp then
            local boxGui = hrp:FindFirstChild("BurLixBoxGui")
            if not boxGui then
                boxGui = Instance.new("BillboardGui")
                boxGui.Name = "BurLixBoxGui"
                boxGui.Size = UDim2.new(4.5, 0, 6, 0)
                boxGui.AlwaysOnTop = true
                boxGui.ResetOnSpawn = false
                
                local boxFrame = Instance.new("Frame")
                boxFrame.Size = UDim2.new(1, 0, 1, 0)
                boxFrame.BackgroundTransparency = 1
                boxFrame.BorderSizePixel = 0
                boxFrame.Parent = boxGui
                
                local stroke = Instance.new("UIStroke")
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Parent = boxFrame
            end
            
            boxGui.Size = UDim2.new(4.5, 0, 6, 0)
            local boxFrame = boxGui:FindFirstChild("Frame")
            if boxFrame then
                local stroke = boxFrame:FindFirstChild("UIStroke")
                if stroke then
                    stroke.Color = boxColor
                    stroke.Thickness = boxThickness
                    stroke.Transparency = boxTransparency
                end
            end
            
            boxGui.Parent = hrp
        end
    else
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local boxGui = hrp:FindFirstChild("BurLixBoxGui")
            if boxGui then
                boxGui:Destroy()
            end
        end
    end
    
    -- BillboardGui (Names) overhead tag handling
    if namesEnabled then
        local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 2)
        if head then
            local billboard = head:FindFirstChild("BurLixNameTag")
            if not billboard then
                billboard = Instance.new("BillboardGui")
                billboard.Name = "BurLixNameTag"
                billboard.Size = UDim2.new(0, 200, 0, 50)
                billboard.StudsOffset = Vector3.new(0, 2.5, 0)
                billboard.AlwaysOnTop = true
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, 0, 1, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Font = Enum.Font.SourceSansBold
                nameLabel.TextStrokeTransparency = 1 -- Disable default stroke
                nameLabel.TextWrapped = true
                nameLabel.Parent = billboard
                
                local stroke = Instance.new("UIStroke")
                stroke.Color = Color3.fromRGB(0, 0, 0)
                stroke.Thickness = nameStrokeThickness
                stroke.Parent = nameLabel
            end
            
            local nameLabel = billboard:FindFirstChild("TextLabel")
            if nameLabel then
                nameLabel.Text = targetPlayer.DisplayName or targetPlayer.Name
                nameLabel.TextColor3 = nameColor
                nameLabel.TextSize = nameSize
                
                local stroke = nameLabel:FindFirstChild("UIStroke")
                if stroke then
                    stroke.Thickness = nameStrokeThickness
                end
            end
            
            billboard.Parent = head
        end
    else
        local head = char:FindFirstChild("Head")
        if head then
            local billboard = head:FindFirstChild("BurLixNameTag")
            if billboard then
                billboard:Destroy()
            end
        end
    end
end

-- Refresh visuals for all players currently in game
local function refreshAllVisuals()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            task.spawn(function()
                updateCharacterVisuals(p, p.Character)
            end)
        end
    end
end

-- Hook player and character events to apply visuals dynamically
local function onPlayerAdded(p)
    local conn = p.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        task.spawn(function()
            updateCharacterVisuals(p, char)
        end)
    end)
    table.insert(connections, conn)
    
    if p.Character then
        task.spawn(function()
            updateCharacterVisuals(p, p.Character)
        end)
    end
end

table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
for _, p in ipairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end

-- ==================== PLAYER TAB CONTENTS ====================

-- WalkSpeed Slider
local wsRow, updateWSSlider = createSlider(playerTab, "Walk Speed", 16, 200, currentWalkSpeed, 1, function(val)
    currentWalkSpeed = val
    if humanoid then
        pcall(function() humanoid.WalkSpeed = val end)
    end
end)
updateWSSliderUI = updateWSSlider

-- JumpPower Slider
local jpRow, updateJPSlider = createSlider(playerTab, "Jump Ability", minJump, maxJump, currentJumpValue, 2, function(val)
    currentJumpValue = val
    if humanoid then
        pcall(function()
            if humanoid.UseJumpPower then
                humanoid.JumpPower = val
            else
                humanoid.JumpHeight = val
            end
        end)
    end
end)
updateJPSliderUI = updateJPSlider


-- ==================== WORLD TAB CONTENTS ====================

-- Gravity Slider
local gravitySliderRow, updateGravitySlider = createSlider(worldTab, "Gravity", 0, 500, Workspace.Gravity, 1, function(val)
    pcall(function() Workspace.Gravity = val end)
end)


-- ==================== AUTHORS TAB CONTENTS ====================

-- Creators Info (Separated thank you footer to prevent clipping)
local creatorsCard = createRow(authorsTab, "CreatorsCard", 120, 1)

local creatorsLabel = Instance.new("TextLabel")
creatorsLabel.Size = UDim2.new(1, -20, 0, 75)
creatorsLabel.Position = UDim2.new(0, 10, 0, 5)
creatorsLabel.BackgroundTransparency = 1
creatorsLabel.Text = "BurLix HUB v1.7.0\n\nCreators:\n- Vench1k\n- Gemini"
creatorsLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
creatorsLabel.TextSize = 13
creatorsLabel.Font = Enum.Font.SourceSansBold
creatorsLabel.TextXAlignment = Enum.TextXAlignment.Left
creatorsLabel.TextYAlignment = Enum.TextYAlignment.Top
creatorsLabel.LineHeight = 1.3
creatorsLabel.TextWrapped = true
creatorsLabel.Parent = creatorsCard
registerThemeElement(creatorsLabel, "Text")

local thankYouLabel = Instance.new("TextLabel")
thankYouLabel.Size = UDim2.new(1, -20, 0, 20)
thankYouLabel.Position = UDim2.new(0, 10, 1, -25)
thankYouLabel.BackgroundTransparency = 1
thankYouLabel.Text = "Thank you for using BurLix HUB."
thankYouLabel.TextColor3 = Color3.fromRGB(150, 150, 155)
thankYouLabel.TextSize = 12
thankYouLabel.Font = Enum.Font.SourceSans
thankYouLabel.TextXAlignment = Enum.TextXAlignment.Left
thankYouLabel.TextWrapped = true
thankYouLabel.Parent = creatorsCard
registerThemeElement(thankYouLabel, "Text")

-- Changelog Card (Taller to comfortably fit wrapped version history text)
local changelogCard = createRow(authorsTab, "ChangelogCard", 195, 2)

local changelogLabel = Instance.new("TextLabel")
changelogLabel.Size = UDim2.new(1, -20, 1, -10)
changelogLabel.Position = UDim2.new(0, 10, 0, 5)
changelogLabel.BackgroundTransparency = 1
changelogLabel.Text = "Changelog v1.7.0:\n- Added dynamic menu resizing by dragging the bottom-right corner.\n- Added 4 new beautiful themes (Cyberpunk, Forest, Nordic, Sunset).\n- Redesigned the theme selection row with a horizontal scrollbar."
changelogLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
changelogLabel.TextSize = 12
changelogLabel.Font = Enum.Font.SourceSans
changelogLabel.TextXAlignment = Enum.TextXAlignment.Left
changelogLabel.TextYAlignment = Enum.TextYAlignment.Top
changelogLabel.LineHeight = 1.3
changelogLabel.TextWrapped = true
changelogLabel.Parent = changelogCard
registerThemeElement(changelogLabel, "Text")

-- User Info Card
local infoRow = createRow(authorsTab, "InfoRow", 100, 3)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 1, -10)
infoLabel.Position = UDim2.new(0, 10, 0, 5)
infoLabel.BackgroundTransparency = 1

local username = player.Name or "Unknown"
local displayName = player.DisplayName or username
local accountAge = 0
pcall(function()
    accountAge = player.AccountAge or 0
end)

infoLabel.Text = string.format("User: %s\nDisplay: %s\nAccount Age: %s days\nPlatform: Roblox Client", username, displayName, tostring(accountAge))
infoLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
infoLabel.TextSize = 13
infoLabel.Font = Enum.Font.SourceSans
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.LineHeight = 1.3
infoLabel.TextWrapped = true
infoLabel.Parent = infoRow
registerThemeElement(infoLabel, "Text")


-- ==================== VISUALS TAB CONTENTS ====================

local highlightSettingsPanel, highlightSettingsHeight
local highlightRow = createToggle(visualsTab, "Enable Highlighting", false, 1, function(state)
    highlightEnabled = state
    refreshAllVisuals()
end, function()
    if highlightSettingsPanel and highlightSettingsHeight then
        toggleSettingsPanel(highlightSettingsPanel, highlightSettingsHeight)
    end
end)

highlightSettingsPanel, highlightSettingsHeight = createSettingsPanel(visualsTab, 2, highlightColor, function(color)
    highlightColor = color
    refreshAllVisuals()
end, {
    {
        name = "Fill Trans",
        min = 0,
        max = 1,
        default = highlightTransparency,
        onChange = function(val)
            highlightTransparency = val
            refreshAllVisuals()
        end
    },
    {
        name = "Outline Trans",
        min = 0,
        max = 1,
        default = highlightOutlineTransparency,
        onChange = function(val)
            highlightOutlineTransparency = val
            refreshAllVisuals()
        end
    }
})

local borderSettingsPanel, borderSettingsHeight
local borderRow = createToggle(visualsTab, "Enable Borders", false, 3, function(state)
    bordersEnabled = state
    refreshAllVisuals()
end, function()
    if borderSettingsPanel and borderSettingsHeight then
        toggleSettingsPanel(borderSettingsPanel, borderSettingsHeight)
    end
end)

borderSettingsPanel, borderSettingsHeight = createSettingsPanel(visualsTab, 4, borderColor, function(color)
    borderColor = color
    refreshAllVisuals()
end, {
    {
        name = "Outline Trans",
        min = 0,
        max = 1,
        default = borderTransparency,
        onChange = function(val)
            borderTransparency = val
            refreshAllVisuals()
        end
    }
})

local nameSettingsPanel, nameSettingsHeight
local nameRow = createToggle(visualsTab, "Show Names", false, 5, function(state)
    namesEnabled = state
    refreshAllVisuals()
end, function()
    if nameSettingsPanel and nameSettingsHeight then
        toggleSettingsPanel(nameSettingsPanel, nameSettingsHeight)
    end
end)

nameSettingsPanel, nameSettingsHeight = createSettingsPanel(visualsTab, 6, nameColor, function(color)
    nameColor = color
    refreshAllVisuals()
end, {
    {
        name = "Font Size",
        min = 10,
        max = 24,
        default = nameSize,
        onChange = function(val)
            nameSize = val
            refreshAllVisuals()
        end
    },
    {
        name = "Stroke Thick",
        min = 0,
        max = 4,
        default = nameStrokeThickness,
        onChange = function(val)
            nameStrokeThickness = val
            refreshAllVisuals()
        end
    }
})

local boxSettingsPanel, boxSettingsHeight
local boxRow = createToggle(visualsTab, "Show Boxes", false, 7, function(state)
    boxesEnabled = state
    refreshAllVisuals()
end, function()
    if boxSettingsPanel and boxSettingsHeight then
        toggleSettingsPanel(boxSettingsPanel, boxSettingsHeight)
    end
end)

boxSettingsPanel, boxSettingsHeight = createSettingsPanel(visualsTab, 8, boxColor, function(color)
    boxColor = color
    refreshAllVisuals()
end, {
    {
        name = "Thickness",
        min = 1,
        max = 5,
        default = boxThickness,
        onChange = function(val)
            boxThickness = val
            refreshAllVisuals()
        end
    },
    {
        name = "Transparency",
        min = 0,
        max = 1,
        default = boxTransparency,
        onChange = function(val)
            boxTransparency = val
            refreshAllVisuals()
        end
    }
})


-- ==================== LOGIC AND INTERACTION ====================

-- Completely unload the script / destroy GUI on Close Button click (With active connections & visuals cleanup)
local unloaded = false
local function unload()
    if unloaded then return end
    unloaded = true
    
    highlightEnabled = false
    bordersEnabled = false
    namesEnabled = false
    boxesEnabled = false
    pcall(refreshAllVisuals)
    
    -- Disconnect all active connections
    for _, conn in ipairs(connections) do
        if conn and conn.Connected then
            pcall(function() conn:Disconnect() end)
        end
    end
    table.clear(connections)
    
    pcall(function()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)
end

table.insert(connections, closeButton.MouseButton1Click:Connect(unload))
table.insert(connections, settingsButton.MouseButton1Click:Connect(function()
    if activeTabName == "Settings" then
        showTab(lastActiveTab)
    else
        showTab("Settings")
    end
end))
table.insert(connections, screenGui.Destroying:Connect(unload))

-- Toggle Menu Visibility with Keybind
table.insert(connections, UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == menuKeybind then
        toggleUI()
    end
end))

-- Main Frame Dragging Logic
local dragging = false
local dragInput
local dragStart
local startPos

local function updateMain(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

table.insert(connections, titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        local changedConn
        changedConn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if changedConn then
                    changedConn:Disconnect()
                end
            end
        end)
    end
end))

table.insert(connections, titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))

-- Island Dragging Logic
local islandDragging = false
local islandDragInput
local islandDragStart
local islandStartPos

local function updateIsland(input)
    local delta = input.Position - islandDragStart
    islandFrame.Position = UDim2.new(islandStartPos.X.Scale, islandStartPos.X.Offset + delta.X, islandStartPos.Y.Scale, islandStartPos.Y.Offset + delta.Y)
end

table.insert(connections, islandFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        islandDragging = true
        islandDragStart = input.Position
        islandStartPos = islandFrame.Position
        
        local changedConn
        changedConn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                islandDragging = false
                if changedConn then
                    changedConn:Disconnect()
                end
            end
        end)
    end
end))

table.insert(connections, islandFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        islandDragInput = input
    end
end))

-- Bind combined UserInput drag updates
table.insert(connections, UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateMain(input)
    elseif input == islandDragInput and islandDragging then
        updateIsland(input)
    elseif input == resizeDragInput and resizing then
        updateResize(input)
    end
end))

-- FPS and Ping Tracking Logic (Using high performance os.clock() instead of tick())
local lastIteration = os.clock()
local frameCount = 0
table.insert(connections, RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local currentTime = os.clock()
    if currentTime - lastIteration >= 1 then
        local fps = math.round(frameCount / (currentTime - lastIteration))
        islandFPS.Text = "FPS: " .. tostring(fps)
        frameCount = 0
        lastIteration = currentTime
        
        -- Approximate round-trip ping in milliseconds
        local ping = 0
        pcall(function()
            ping = player:GetNetworkPing() or 0
        end)
        islandPing.Text = "Ping: " .. string.format("%.0f ms", ping * 1000)
    end
end))