-- BurLixHUB.lua
-- A standard Roblox LocalScript for testing character physics and UI layouts in Roblox Studio.
-- Place this script in StarterPlayer -> StarterPlayerScripts or StarterGui.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

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

-- Fallback Settings
local currentWalkSpeed = 16
local isJumpPower = true
local currentJumpValue = 50
local minJump = 0
local maxJump = 250

local humanoid = nil
local character = nil

-- Visuals State variables
local highlightEnabled = false
local bordersEnabled = false
local namesEnabled = false
local boxesEnabled = false

-- Connections list to disconnect on unload to prevent leaks
local connections = {}

-- Create GUI Elements early to guarantee UI is loaded
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BurLixGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = targetParent

-- Main Frame (Wider to accommodate left tab sidebar)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 460, 0, 320)
mainFrame.Position = UDim2.new(0.5, -230, 0.5, -160)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

-- UI Corner for Main Frame (Less rounded)
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 4)
mainCorner.Parent = mainFrame

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 45)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 4)
titleCorner.Parent = titleBar

-- Title Text
local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Size = UDim2.new(1, -60, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "BurLix HUB v1.4.1"
titleText.TextColor3 = Color3.fromRGB(240, 240, 245)
titleText.TextSize = 18
titleText.Font = Enum.Font.SourceSansBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- Title Bar Separator Line
local titleSeparator = Instance.new("Frame")
titleSeparator.Name = "Separator"
titleSeparator.Size = UDim2.new(1, 0, 0, 1)
titleSeparator.Position = UDim2.new(0, 0, 0, 44)
titleSeparator.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
titleSeparator.BorderSizePixel = 0
titleSeparator.Parent = titleBar

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

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 3)
closeCorner.Parent = closeButton

-- Close Button Hover/Click Styles
closeButton.MouseEnter:Connect(function()
    closeButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
end)
closeButton.MouseLeave:Connect(function()
    closeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
end)

-- Navigation Panel (Sidebar)
local navPanel = Instance.new("Frame")
navPanel.Name = "NavigationPanel"
navPanel.Size = UDim2.new(0, 110, 1, -45)
navPanel.Position = UDim2.new(0, 0, 0, 45)
navPanel.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
navPanel.BorderSizePixel = 0
navPanel.Parent = mainFrame

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
    for name, data in pairs(tabs) do
        if name == tabName then
            data.Button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            data.Frame.Visible = true
        else
            data.Button.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
            data.Frame.Visible = false
        end
    end
end

local function createTab(name, layoutOrder, canvasHeight)
    -- Navigation Button
    local btn = Instance.new("TextButton")
    btn.Name = name .. "TabButton"
    btn.Size = UDim2.new(1, 0, 0, 32)
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

    return row, updateSlider
end

-- Helper Function to Create Toggles
local function createToggle(tabFrame, name, defaultVal, layoutOrder, onChange)
    local row = createRow(tabFrame, name .. "Row", 45, layoutOrder)
    
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
    
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 40, 0, 20)
    toggleButton.Position = UDim2.new(1, -50, 0.5, -10)
    toggleButton.BackgroundColor3 = defaultVal and Color3.fromRGB(80, 80, 250) or Color3.fromRGB(35, 35, 40)
    toggleButton.Text = ""
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
    knobCorner.Parent = knob
    
    local enabled = defaultVal
    
    toggleButton.MouseButton1Click:Connect(function()
        enabled = not enabled
        local targetColor = enabled and Color3.fromRGB(80, 80, 250) or Color3.fromRGB(35, 35, 40)
        local targetPos = enabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        
        TweenService:Create(toggleButton, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
        
        onChange(enabled)
    end)
    
    return row
end

-- Create Tabs (Decreased Authors tab canvas height since Reset buttons are removed)
local playerTab = createTab("Player", 1, 200)
local worldTab = createTab("World", 2, 200)
local authorsTab = createTab("Authors", 3, 520)
local visualsTab = createTab("Visuals", 4, 250)

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
        highlight.FillColor = Color3.fromRGB(80, 80, 250)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = highlightEnabled and 0.5 or 1
        highlight.OutlineTransparency = bordersEnabled and 0 or 1
    else
        if highlight then
            highlight:Destroy()
        end
    end
    
    -- SelectionBox (Boxes) handling
    local box = char:FindFirstChild("BurLixBox")
    if boxesEnabled then
        if not box then
            box = Instance.new("SelectionBox")
            box.Name = "BurLixBox"
            box.Color3 = Color3.fromRGB(80, 80, 250)
            box.LineThickness = 0.05
            box.Adornee = char
            box.Parent = char
        end
    else
        if box then
            box:Destroy()
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
                nameLabel.Text = targetPlayer.DisplayName or targetPlayer.Name
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.TextSize = 14
                nameLabel.Font = Enum.Font.SourceSansBold
                nameLabel.TextStrokeTransparency = 0
                nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                nameLabel.TextWrapped = true
                nameLabel.Parent = billboard
                
                billboard.Parent = head
            end
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
creatorsLabel.Text = "BurLix HUB v1.4.1\n\nCreators:\n- Vench1k\n- Gemini"
creatorsLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
creatorsLabel.TextSize = 13
creatorsLabel.Font = Enum.Font.SourceSansBold
creatorsLabel.TextXAlignment = Enum.TextXAlignment.Left
creatorsLabel.TextYAlignment = Enum.TextYAlignment.Top
creatorsLabel.LineHeight = 1.3
creatorsLabel.TextWrapped = true
creatorsLabel.Parent = creatorsCard

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

-- Changelog Card (Taller to comfortably fit wrapped version history text)
local changelogCard = createRow(authorsTab, "ChangelogCard", 195, 2)

local changelogLabel = Instance.new("TextLabel")
changelogLabel.Size = UDim2.new(1, -20, 1, -10)
changelogLabel.Position = UDim2.new(0, 10, 0, 5)
changelogLabel.BackgroundTransparency = 1
changelogLabel.Text = "Changelog v1.4.1:\n- Added 3D SelectionBox ESP (Show Boxes) to the Visuals tab.\n- Adjusted Visuals tab canvas height to support the new toggle.\n- Fixed all Visuals (Highlighting, Borders, Names) to work correctly for all players (including local player).\n- Added memory leak cleanup that disconnects all listeners on unload."
changelogLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
changelogLabel.TextSize = 12
changelogLabel.Font = Enum.Font.SourceSans
changelogLabel.TextXAlignment = Enum.TextXAlignment.Left
changelogLabel.TextYAlignment = Enum.TextYAlignment.Top
changelogLabel.LineHeight = 1.3
changelogLabel.TextWrapped = true
changelogLabel.Parent = changelogCard

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


-- ==================== VISUALS TAB CONTENTS ====================

-- Toggle for Highlighting
createToggle(visualsTab, "Enable Highlighting", false, 1, function(state)
    highlightEnabled = state
    refreshAllVisuals()
end)

-- Toggle for Borders
createToggle(visualsTab, "Enable Borders", false, 2, function(state)
    bordersEnabled = state
    refreshAllVisuals()
end)

-- Toggle for Show Names
createToggle(visualsTab, "Show Names", false, 3, function(state)
    namesEnabled = state
    refreshAllVisuals()
end)

-- Toggle for Show Boxes
createToggle(visualsTab, "Show Boxes", false, 4, function(state)
    boxesEnabled = state
    refreshAllVisuals()
end)


-- ==================== TOP STATS ISLAND ====================

local islandFrame = Instance.new("Frame")
islandFrame.Name = "IslandFrame"
islandFrame.Size = UDim2.new(0, 380, 0, 35)
islandFrame.Position = UDim2.new(0.5, -190, 0, 15)
islandFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
islandFrame.BorderSizePixel = 0
islandFrame.Active = true
islandFrame.Draggable = true
islandFrame.Parent = screenGui

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
local function createIslandLabel(text, sizeX, layoutOrder)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, sizeX, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.TextSize = 12
    label.Font = Enum.Font.SourceSansBold
    label.LayoutOrder = layoutOrder
    label.Parent = islandFrame
    return label
end

local islandTitle = createIslandLabel("BurLix HUB", 65, 1)
islandTitle.TextColor3 = Color3.fromRGB(80, 80, 250)

-- Vertical Separator on Island
local islandSeparator = Instance.new("Frame")
islandSeparator.Name = "Separator"
islandSeparator.Size = UDim2.new(0, 1, 0, 18)
islandSeparator.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
islandSeparator.BorderSizePixel = 0
islandSeparator.LayoutOrder = 2
islandSeparator.Parent = islandFrame

local islandUser = createIslandLabel(player.DisplayName or player.Name or "Player", 80, 3)
islandUser.TextTruncate = Enum.TextTruncate.AtEnd

local islandFPS = createIslandLabel("FPS: --", 50, 4)
local islandPing = createIslandLabel("Ping: --", 60, 5)

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

local toggleCornerBtn = Instance.new("UICorner")
toggleCornerBtn.CornerRadius = UDim.new(0, 3)
toggleCornerBtn.Parent = islandToggle


-- ==================== LOGIC AND INTERACTION ====================

local function toggleUI()
    mainFrame.Visible = not mainFrame.Visible
end

table.insert(connections, islandToggle.MouseButton1Click:Connect(toggleUI))

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
table.insert(connections, screenGui.Destroying:Connect(unload))

-- Toggle Menu Visibility with Key P
table.insert(connections, UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.P then
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