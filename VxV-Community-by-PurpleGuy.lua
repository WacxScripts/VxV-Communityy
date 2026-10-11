--[[
    ═════════════════════════════════════════════════════════════
                          VxV-Community
       Blood Moon Engine (Direct House Paths & Secret Edition)
    ═════════════════════════════════════════════════════════════
]]

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- Cleanup existing instances
if CoreGui:FindFirstChild("VxV_BloodMoonHub_Gui") then
    CoreGui.VxV_BloodMoonHub_Gui:Destroy()
end
if PlayerGui:FindFirstChild("VxV_BloodMoonHub_Gui") then
    PlayerGui.VxV_BloodMoonHub_Gui:Destroy()
end

---------------------------------------------------------
-- CONFIGURATION & DATA SAVING (JSON)
---------------------------------------------------------
local CONFIG_FILE_NAME = "BloodMoonHub_Config.json"

local config = {
	IsAutoFarmActive = false,
	IsAutoHatchActive = false,
	IsAutoKnockActive = false,
	IsAutoCollectOrbsActive = false,
	IsAutoBossActive = false,
	TweenSpeed = "140",
	IsAntiAfkActive = true
}

local function saveConfig()
	if writefile then
		pcall(function()
			writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(config))
		end)
	end
end

local function loadConfig()
	if isfile and readfile and isfile(CONFIG_FILE_NAME) then
		pcall(function()
			local raw = readfile(CONFIG_FILE_NAME)
			local decoded = HttpService:JSONDecode(raw)
			if type(decoded) == "table" then
				if decoded.IsAutoFarmActive ~= nil then config.IsAutoFarmActive = decoded.IsAutoFarmActive end
				if decoded.IsAutoHatchActive ~= nil then config.IsAutoHatchActive = decoded.IsAutoHatchActive end
				if decoded.IsAutoKnockActive ~= nil then config.IsAutoKnockActive = decoded.IsAutoKnockActive end
				if decoded.IsAutoCollectOrbsActive ~= nil then config.IsAutoCollectOrbsActive = decoded.IsAutoCollectOrbsActive end
				if decoded.IsAutoBossActive ~= nil then config.IsAutoBossActive = decoded.IsAutoBossActive end
				if decoded.TweenSpeed then config.TweenSpeed = tostring(decoded.TweenSpeed) end
				if decoded.IsAntiAfkActive ~= nil then config.IsAntiAfkActive = decoded.IsAntiAfkActive end
			end
		end)
	end
end

loadConfig()

---------------------------------------------------------
-- BLOOD MOON SHADER COLOR PALETTE
---------------------------------------------------------
local THEME = {
	MainBG        = Color3.fromRGB(14, 9, 18),
	TopBarBG      = Color3.fromRGB(24, 12, 32),
	SidebarBG     = Color3.fromRGB(18, 10, 24),
	CardBG        = Color3.fromRGB(26, 14, 36),
	InputBG       = Color3.fromRGB(36, 18, 48),
	CrimsonAccent = Color3.fromRGB(230, 25, 60),
	BloodBorder   = Color3.fromRGB(140, 20, 60),
	TextPrimary   = Color3.fromRGB(255, 230, 235),
	TextMuted     = Color3.fromRGB(180, 130, 150)
}

---------------------------------------------------------
-- FORWARD DECLARATIONS
---------------------------------------------------------
local startAutoFarmLoop, startAutoHatchLoop, startAutoKnockLoop, startAutoBossLoop, startAutoCollectOrbsLoop

---------------------------------------------------------
-- TWEEN CONTROLLER & CANCELLATION SYSTEM
---------------------------------------------------------
local currentActiveTween = nil

local function stopCurrentTween()
	if currentActiveTween then
		pcall(function() currentActiveTween:Cancel() end)
		currentActiveTween = nil
	end
end

---------------------------------------------------------
-- GENERAL TWEEN UTILITY
---------------------------------------------------------
local function tweenToPart(targetPart)
	local character = LocalPlayer.Character
	if not character then return false end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not targetPart or not targetPart.Parent then return false end

	local targetCFrame
	if targetPart:IsA("BasePart") then
		targetCFrame = targetPart.CFrame
	elseif targetPart:IsA("Model") then
		targetCFrame = targetPart:GetPivot()
	else
		return false
	end

	targetCFrame = targetCFrame + Vector3.new(0, 2, 0)

	local distance = (hrp.Position - targetCFrame.Position).Magnitude
	local speed = tonumber(config.TweenSpeed) or 140
	if speed <= 0 then speed = 140 end

	local tweenTime = math.clamp(distance / speed, 0.03, 6)
	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)

	stopCurrentTween()

	local success = pcall(function()
		currentActiveTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
		currentActiveTween:Play()
		currentActiveTween.Completed:Wait()
	end)

	currentActiveTween = nil
	return success
end

---------------------------------------------------------
-- CLOSEST EGG RESOLVER
---------------------------------------------------------
local function getClosestEggId()
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local things = Workspace:FindFirstChild("__THINGS")
	if not things then return nil end

	local customEggs = things:FindFirstChild("CustomEggs")
	if not customEggs then return nil end

	local closestId = nil
	local shortestDistance = math.huge

	for _, eggModel in ipairs(customEggs:GetChildren()) do
		local targetPart = eggModel:IsA("BasePart") and eggModel or eggModel:FindFirstChildWhichIsA("BasePart", true) or (eggModel:IsA("Model") and eggModel.PrimaryPart)
		
		if targetPart then
			local distance = (hrp.Position - targetPart.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				closestId = eggModel.Name
			end
		end
	end

	return closestId
end

---------------------------------------------------------
-- BOSS REMOTE INVOCATIONS
---------------------------------------------------------
local function invokeBossStart()
	local args = {
		"HatchWar",
		"HW_Boss_Start",
		4
	}
	pcall(function()
		ReplicatedStorage:WaitForChild("Network"):WaitForChild("Instancing_InvokeCustomFromClient"):InvokeServer(unpack(args))
	end)
end

local function sendBossRemote(payload)
	local net = ReplicatedStorage:FindFirstChild("Network")
	if not net then return end
	pcall(function()
		local invokeRemote = net:FindFirstChild("Instancing_InvokeCustomFromClient")
		if invokeRemote then invokeRemote:InvokeServer("HatchWar", "HW_Boss_Tap", payload) end

		local fireRemote = net:FindFirstChild("Instancing_FireCustomFromClient")
		if fireRemote then fireRemote:FireServer("HatchWar", "HW_Boss_Tap", payload) end
	end)
end

---------------------------------------------------------
-- HIGH-SPEED BURST AUTO-HATCH LOOP
---------------------------------------------------------
startAutoHatchLoop = function()
	task.spawn(function()
		local targetEggId = nil

		while config.IsAutoHatchActive and not targetEggId do
			targetEggId = getClosestEggId()
			if not targetEggId then
				task.wait(0.1)
			end
		end

		if not targetEggId then return end

		local hatchRemote = ReplicatedStorage:WaitForChild("Network"):WaitForChild("CustomEggs_Hatch")

		while config.IsAutoHatchActive do
			for _ = 1, 15 do
				task.spawn(function()
					pcall(function()
						hatchRemote:InvokeServer(targetEggId, 78)
					end)
				end)
			end
			task.wait()
		end
	end)
end

---------------------------------------------------------
-- AUTO KNOCK DOORS (DIRECT HOUSE PATHS WITH TWEENING)
---------------------------------------------------------
startAutoKnockLoop = function()
	task.spawn(function()
		local net = ReplicatedStorage:WaitForChild("Network")
		local knockRemote = net:WaitForChild("Instancing_InvokeCustomFromClient")

		local houseSteps = {
			{
				id = 1,
				pathFunc = function()
					return Workspace.__THINGS.__INSTANCE_CONTAINER.Active.HatchWar["6 | Count's Manor"].Houses.House1
				end
			},
			{
				id = 2,
				pathFunc = function()
					return Workspace.__THINGS.__INSTANCE_CONTAINER.Active.HatchWar["6 | Count's Manor"].Houses.House2
				end
			},
			{
				id = 3,
				pathFunc = function()
					return Workspace.__THINGS.__INSTANCE_CONTAINER.Active.HatchWar["6 | Count's Manor"].Houses.House3
				end
			},
			{
				id = 4,
				pathFunc = function()
					return Workspace.__THINGS.__INSTANCE_CONTAINER.Active.HatchWar["6 | Count's Manor"].Houses.House4
				end
			},
			{
				id = 5,
				pathFunc = function()
					return Workspace.__THINGS.__INSTANCE_CONTAINER.Active.HatchWar["6 | Count's Manor"].Houses.House5
				end
			},
			{
				id = 6,
				pathFunc = function()
					return Workspace.__THINGS.__INSTANCE_CONTAINER.Active.HatchWar["6 | Count's Manor"].Houses.House6
				end
			},
			{
				id = 7,
				pathFunc = function()
					return Workspace.__THINGS.__INSTANCE_CONTAINER.Active.HatchWar["6 | Count's Manor"].Houses.House7
				end
			},
			{
				id = 8,
				pathFunc = function()
					return Workspace.__THINGS.__INSTANCE_CONTAINER.Active.HatchWar["6 | Count's Manor"].Houses.House8
				end
			}
		}

		while config.IsAutoKnockActive do
			for _, step in ipairs(houseSteps) do
				if not config.IsAutoKnockActive then break end

				pcall(function()
					local targetObj = step.pathFunc()
					if targetObj then
						local targetPart = nil
						if targetObj:IsA("BasePart") then
							targetPart = targetObj
						elseif targetObj:IsA("Model") then
							targetPart = targetObj.PrimaryPart or targetObj:FindFirstChildWhichIsA("BasePart", true)
						elseif targetObj:IsA("Instance") then
							targetPart = targetObj:FindFirstChildWhichIsA("BasePart", true)
						end

						if targetPart then
							tweenToPart(targetPart)
						end
					end
				end)

				for _ = 1, 5 do
					if not config.IsAutoKnockActive then break end
					pcall(function()
						local args = {
							"HatchWar",
							"HW_Doors_Knock",
							step.id
						}
						knockRemote:InvokeServer(unpack(args))
					end)
					task.wait(0.125)
				end
			end
			task.wait()
		end
	end)
end

---------------------------------------------------------
-- AUTO FARM (150-STUD RANGE MULTI-WORKER SYSTEM)
---------------------------------------------------------
startAutoFarmLoop = function()
	task.spawn(function()
		local damageRemote = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Breakables_PlayerDealDamage")
		local trackedBreakables = {}

		while config.IsAutoFarmActive do
			local character = LocalPlayer.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local breakablesFolder = Workspace:FindFirstChild("__THINGS") and Workspace.__THINGS:FindFirstChild("Breakables")

			if hrp and breakablesFolder then
				local hrpPos = hrp.Position
				for _, breakable in ipairs(breakablesFolder:GetChildren()) do
					if not config.IsAutoFarmActive then break end

					local bPart = breakable:IsA("BasePart") and breakable or (breakable:IsA("Model") and (breakable.PrimaryPart or breakable:FindFirstChildWhichIsA("BasePart")))
					if bPart then
						if (hrpPos - bPart.Position).Magnitude <= 150 then
							local breakableId = breakable.Name
							if not trackedBreakables[breakableId] then
								trackedBreakables[breakableId] = true
								task.spawn(function()
									while config.IsAutoFarmActive and breakable.Parent do
										local currHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
										if not currHrp or (currHrp.Position - bPart.Position).Magnitude > 165 then break end
										
										pcall(function()
											for _ = 1, 20 do
												damageRemote:FireServer(breakableId)
											end
										end)
										task.wait()
									end
									trackedBreakables[breakableId] = nil
								end)
							end
						end
					end
				end
			end

			task.wait(0.05)
		end
		table.clear(trackedBreakables)
	end)
end

---------------------------------------------------------
-- INDIVIDUAL LOOPS
---------------------------------------------------------
startAutoBossLoop = function()
	task.spawn(function()
		while config.IsAutoBossActive do
			invokeBossStart()
			sendBossRemote("screen")
			task.wait(0.1)
		end
	end)
end

startAutoCollectOrbsLoop = function()
	task.spawn(function()
		while config.IsAutoCollectOrbsActive do
			local orbFolder = Workspace:FindFirstChild("HatchWarOrbs", true)
			if orbFolder then
				for _, orb in ipairs(orbFolder:GetChildren()) do
					if not config.IsAutoCollectOrbsActive then break end
					local mainPart = orb:IsA("BasePart") and orb or orb:FindFirstChildWhichIsA("BasePart", true) or (orb:IsA("Model") and orb.PrimaryPart)
					if mainPart then tweenToPart(mainPart) end
				end
			end
			task.wait(0.25)
		end
	end)
end

---------------------------------------------------------
-- BLOOD MOON SHADER THEME GUI CREATION
---------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VxV_BloodMoonHub_Gui"
ScreenGui.ResetOnSpawn = false

local parentSuccess = pcall(function() ScreenGui.Parent = CoreGui end)
if not parentSuccess or not ScreenGui.Parent then ScreenGui.Parent = PlayerGui end

-- Floating Action Toggle Button
local FloatingToggle = Instance.new("TextButton")
FloatingToggle.Name = "FloatingToggle"
FloatingToggle.Size = UDim2.new(0, 56, 0, 56)
FloatingToggle.Position = UDim2.new(0, 20, 0.5, -28)
FloatingToggle.BackgroundColor3 = THEME.TopBarBG
FloatingToggle.Text = "🩸\nVxV"
FloatingToggle.TextColor3 = THEME.CrimsonAccent
FloatingToggle.TextSize = 13
FloatingToggle.Font = Enum.Font.GothamBold
FloatingToggle.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(0, 14)
FloatCorner.Parent = FloatingToggle

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = THEME.CrimsonAccent
FloatStroke.Thickness = 2
FloatStroke.Parent = FloatingToggle

-- Dragging Support
local floatDragging, floatDragStart, floatStartPos
FloatingToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        floatDragging = true
        floatDragStart = input.Position
        floatStartPos = FloatingToggle.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then floatDragging = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if floatDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - floatDragStart
        FloatingToggle.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
    end
end)

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 620, 0, 420)
MainFrame.Position = UDim2.new(0.5, -310, 0.5, -210)
MainFrame.BackgroundColor3 = THEME.MainBG
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = THEME.BloodBorder
MainStroke.Thickness = 2
MainStroke.Parent = MainFrame

-- Top Bar
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = THEME.TopBarBG
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 12)
TopBarCorner.Parent = TopBar

local LogoLabel = Instance.new("TextLabel")
LogoLabel.Name = "LogoLabel"
LogoLabel.Size = UDim2.new(0, 30, 0, 30)
LogoLabel.Position = UDim2.new(0, 10, 0.5, -15)
LogoLabel.BackgroundTransparency = 1
LogoLabel.Text = "🌙"
LogoLabel.TextSize = 20
LogoLabel.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(0, 170, 1, 0)
TitleLabel.Position = UDim2.new(0, 42, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "VxV Blood Moon"
TitleLabel.TextColor3 = THEME.CrimsonAccent
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local SubtitleLabel = Instance.new("TextLabel")
SubtitleLabel.Name = "SubtitleLabel"
SubtitleLabel.Size = UDim2.new(0, 220, 1, 0)
SubtitleLabel.Position = UDim2.new(0, 185, 0, 0)
SubtitleLabel.BackgroundTransparency = 1
SubtitleLabel.Font = Enum.Font.Gotham
SubtitleLabel.Text = "| Tween Edition"
SubtitleLabel.TextColor3 = THEME.TextMuted
SubtitleLabel.TextSize = 12
SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubtitleLabel.Parent = TopBar

-- Close & Minimize Buttons
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Color3.fromRGB(50, 15, 25)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 90, 110)
CloseBtn.TextSize = 13
CloseBtn.ZIndex = 5
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.Activated:Connect(function() ScreenGui:Destroy() end)

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.Position = UDim2.new(1, -66, 0.5, -13)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 45)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = THEME.TextPrimary
MinimizeBtn.TextSize = 16
MinimizeBtn.ZIndex = 5
MinimizeBtn.Parent = TopBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinimizeBtn

local isMinimized = false
MinimizeBtn.Activated:Connect(function()
    isMinimized = not isMinimized
    TweenService:Create(MainFrame, TweenInfo.new(0.3), {Size = isMinimized and UDim2.new(0, 620, 0, 42) or UDim2.new(0, 620, 0, 420)}):Play()
end)

FloatingToggle.Activated:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Sidebar Navigation
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 165, 1, -42)
Sidebar.Position = UDim2.new(0, 0, 0, 42)
Sidebar.BackgroundColor3 = THEME.SidebarBG
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 6)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 12)
SidebarPadding.PaddingLeft = UDim.new(0, 8)
SidebarPadding.PaddingRight = UDim.new(0, 8)
SidebarPadding.Parent = Sidebar

-- Content Container
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -165, 1, -42)
ContentArea.Position = UDim2.new(0, 165, 0, 42)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local function CreatePage(name)
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Name = name .. "Page"
    Scroll.Size = UDim2.new(1, -20, 1, -20)
    Scroll.Position = UDim2.new(0, 10, 0, 10)
    Scroll.BackgroundTransparency = 1
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 3
    Scroll.ScrollBarImageColor3 = THEME.CrimsonAccent
    Scroll.Visible = false
    Scroll.Parent = ContentArea

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Scroll

    return Scroll
end

local EventPage = CreatePage("Event")
local UtilityPage = CreatePage("Utility")
local SecretPage = CreatePage("Secret")
EventPage.Visible = true

-- Tab Mechanism
local Tabs = {}
local function CreateTab(name, emoji, pageContainer)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Name = name .. "Tab"
    TabBtn.Size = UDim2.new(1, 0, 0, 36)
    TabBtn.BackgroundColor3 = #Tabs == 0 and THEME.CrimsonAccent or THEME.CardBG
    TabBtn.AutoButtonColor = false
    TabBtn.Text = ""
    TabBtn.Parent = Sidebar

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 8)
    BtnCorner.Parent = TabBtn

    local IconLabel = Instance.new("TextLabel")
    IconLabel.Name = "Icon"
    IconLabel.Size = UDim2.new(0, 20, 0, 20)
    IconLabel.Position = UDim2.new(0, 10, 0.5, -10)
    IconLabel.BackgroundTransparency = 1
    IconLabel.Text = emoji
    IconLabel.TextSize = 14
    IconLabel.Parent = TabBtn

    local Label = Instance.new("TextLabel")
    Label.Name = "Label"
    Label.Size = UDim2.new(1, -38, 1, 0)
    Label.Position = UDim2.new(0, 34, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.GothamMedium
    Label.Text = name
    Label.TextColor3 = #Tabs == 0 and Color3.fromRGB(255, 255, 255) or THEME.TextMuted
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = TabBtn

    TabBtn.Activated:Connect(function()
        for _, tab in pairs(Tabs) do
            TweenService:Create(tab.Button, TweenInfo.new(0.2), {BackgroundColor3 = THEME.CardBG}):Play()
            TweenService:Create(tab.Label, TweenInfo.new(0.2), {TextColor3 = THEME.TextMuted}):Play()
            tab.Page.Visible = false
        end
        TweenService:Create(TabBtn, TweenInfo.new(0.2), {BackgroundColor3 = THEME.CrimsonAccent}):Play()
        TweenService:Create(Label, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        pageContainer.Visible = true
    end)

    table.insert(Tabs, {Button = TabBtn, Label = Label, Page = pageContainer})
end

CreateTab("Blood Moon Event", "🩸", EventPage)
CreateTab("Utilities & Config", "⚙️", UtilityPage)
CreateTab("Secret", "🤫", SecretPage)

---------------------------------------------------------
-- UI ELEMENT FACTORIES
---------------------------------------------------------
local function AddSectionHeader(parent, text)
    local Header = Instance.new("TextLabel")
    Header.Size = UDim2.new(1, 0, 0, 22)
    Header.BackgroundTransparency = 1
    Header.Font = Enum.Font.GothamBold
    Header.Text = string.upper(text)
    Header.TextColor3 = THEME.CrimsonAccent
    Header.TextSize = 11
    Header.TextXAlignment = Enum.TextXAlignment.Left
    Header.Parent = parent
end

local function AddToggleWithInput(parent, title, stateKey, inputKey, placeholderText, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 42)
    Frame.BackgroundColor3 = THEME.CardBG
    Frame.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -140, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.Gotham
    Label.Text = title
    Label.TextColor3 = THEME.TextPrimary
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Switch = Instance.new("TextButton")
    Switch.Size = UDim2.new(0, 44, 0, 24)
    Switch.Position = UDim2.new(1, -52, 0.5, -12)
    Switch.BackgroundColor3 = config[stateKey] and THEME.CrimsonAccent or Color3.fromRGB(45, 25, 45)
    Switch.Text = ""
    Switch.AutoButtonColor = false
    Switch.Parent = Frame

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = Switch

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 18, 0, 18)
    Knob.Position = config[stateKey] and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    Knob.BackgroundColor3 = config[stateKey] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 130, 170)
    Knob.Parent = Switch

    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob

    local ClickArea = Instance.new("TextButton")
    ClickArea.Size = inputKey and UDim2.new(1, -130, 1, 0) or UDim2.new(1, 0, 1, 0)
    ClickArea.BackgroundTransparency = 1
    ClickArea.Text = ""
    ClickArea.ZIndex = 3
    ClickArea.Parent = Frame

    local InputBox
    if inputKey then
        InputBox = Instance.new("TextBox")
        InputBox.Size = UDim2.new(0, 65, 0, 26)
        InputBox.Position = UDim2.new(1, -125, 0.5, -13)
        InputBox.BackgroundColor3 = THEME.InputBG
        InputBox.Text = config[inputKey] or ""
        InputBox.PlaceholderText = placeholderText or ""
        InputBox.TextColor3 = THEME.CrimsonAccent
        InputBox.TextSize = 11
        InputBox.Font = Enum.Font.GothamMedium
        InputBox.ClearTextOnFocus = false
        InputBox.ZIndex = 4
        InputBox.Parent = Frame

        local InputCorner = Instance.new("UICorner")
        InputCorner.CornerRadius = UDim.new(0, 6)
        InputCorner.Parent = InputBox

        InputBox.FocusLost:Connect(function()
            config[inputKey] = InputBox.Text
            saveConfig()
        end)
    end

    local active = config[stateKey]
    local function setToggleState(bool)
        active = bool
        config[stateKey] = active
        saveConfig()
        if active then
            TweenService:Create(Switch, TweenInfo.new(0.2), {BackgroundColor3 = THEME.CrimsonAccent}):Play()
            TweenService:Create(Knob, TweenInfo.new(0.2), {Position = UDim2.new(1, -21, 0.5, -9), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        else
            TweenService:Create(Switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 25, 45)}):Play()
            TweenService:Create(Knob, TweenInfo.new(0.2), {Position = UDim2.new(0, 3, 0.5, -9), BackgroundColor3 = Color3.fromRGB(160, 130, 170)}):Play()
        end
        if callback then callback(active, InputBox and InputBox.Text or nil) end
    end

    ClickArea.Activated:Connect(function() setToggleState(not active) end)
    Switch.Activated:Connect(function() setToggleState(not active) end)

    return { SetState = setToggleState }
end

local function AddButton(parent, title, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 34)
    Btn.BackgroundColor3 = THEME.CrimsonAccent
    Btn.Font = Enum.Font.GothamBold
    Btn.Text = title
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.TextSize = 12
    Btn.ZIndex = 3
    Btn.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Btn

    Btn.Activated:Connect(function() if callback then callback() end end)
    return Btn
end

---------------------------------------------------------
-- UI POPULATION & ATTACHMENTS
---------------------------------------------------------

-- PAGE 1: BLOOD MOON EVENT
AddSectionHeader(EventPage, "⚡ Count's Manor Operations")

AddToggleWithInput(EventPage, "Auto Farm (150 Studs)", "IsAutoFarmActive", nil, nil, function(active)
    if active then
        startAutoFarmLoop()
    else
        stopCurrentTween()
    end
end)

AddToggleWithInput(EventPage, "Auto-Hatch (High-Speed Burst)", "IsAutoHatchActive", nil, nil, function(active)
    if active then
        startAutoHatchLoop()
    end
end)

AddToggleWithInput(EventPage, "Auto Knock All Doors (Tweened)", "IsAutoKnockActive", nil, nil, function(active)
    if active then
        startAutoKnockLoop()
    else
        stopCurrentTween()
    end
end)

AddSectionHeader(EventPage, "💀 Individual Controls")

AddToggleWithInput(EventPage, "Auto Boss (Instant Clear)", "IsAutoBossActive", nil, nil, function(active)
    if active then startAutoBossLoop() end
end)

AddToggleWithInput(EventPage, "Auto Tween To Orbs", "IsAutoCollectOrbsActive", "TweenSpeed", "speed", function(active)
    if active then startAutoCollectOrbsLoop() else stopCurrentTween() end
end)

-- PAGE 2: UTILITIES & CONFIG
AddSectionHeader(UtilityPage, "⚙️ Hub Utilities & System")

local function startAntiAfkLoop()
	task.spawn(function()
		while config.IsAntiAfkActive do
			task.wait(180)
			if not config.IsAntiAfkActive then break end
			local character = LocalPlayer.Character
			if character and character:FindFirstChildOfClass("Humanoid") then
				character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end)
end

LocalPlayer.Idled:Connect(function()
	if config.IsAntiAfkActive then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

AddToggleWithInput(UtilityPage, "Anti-AFK Protection", "IsAntiAfkActive", nil, nil, function(active)
    if active then startAntiAfkLoop() end
end)

AddButton(UtilityPage, "Boost FPS / Optimize Scene", function()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.Plastic
            obj.Reflectance = 0
        end
    end
    print("[VxV Blood Moon Hub] Scene optimized!")
end)

AddButton(UtilityPage, "Rejoin Server", function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

AddButton(UtilityPage, "Save Current Settings", function()
    saveConfig()
end)

-- PAGE 3: SECRET SECTION
AddSectionHeader(SecretPage, "🤫 Confidential Section")

local SecretCard = Instance.new("Frame")
SecretCard.Size = UDim2.new(1, 0, 0, 70)
SecretCard.BackgroundColor3 = THEME.CardBG
SecretCard.Parent = SecretPage

local SecretCorner = Instance.new("UICorner")
SecretCorner.CornerRadius = UDim.new(0, 8)
SecretCorner.Parent = SecretCard

local SecretLabel = Instance.new("TextLabel")
SecretLabel.Size = UDim2.new(1, -20, 1, 0)
SecretLabel.Position = UDim2.new(0, 10, 0, 0)
SecretLabel.BackgroundTransparency = 1
SecretLabel.Font = Enum.Font.GothamBold
SecretLabel.Text = "Click the button below to reveal the secret."
SecretLabel.TextColor3 = THEME.TextPrimary
SecretLabel.TextSize = 12
SecretLabel.TextWrapped = true
SecretLabel.Parent = SecretCard

AddButton(SecretPage, "Touch / Open Secret", function()
    SecretLabel.Text = "You Are Gay Zodec17"
    SecretLabel.TextColor3 = THEME.CrimsonAccent
end)

-- Top Bar Dragging Support
local draggingTopBar, dragStartTopBar, startPosTopBar
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingTopBar = true
        dragStartTopBar = input.Position
        startPosTopBar = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then draggingTopBar = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingTopBar and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartTopBar
        MainFrame.Position = UDim2.new(startPosTopBar.X.Scale, startPosTopBar.X.Offset + delta.X, startPosTopBar.Y.Scale, startPosTopBar.Y.Offset + delta.Y)
    end
end)

---------------------------------------------------------
-- INITIAL EXECUTION
---------------------------------------------------------
if config.IsAutoFarmActive then startAutoFarmLoop() end
if config.IsAutoHatchActive then startAutoHatchLoop() end
if config.IsAutoKnockActive then startAutoKnockLoop() end
if config.IsAutoBossActive then startAutoBossLoop() end
if config.IsAutoCollectOrbsActive then startAutoCollectOrbsLoop() end
if config.IsAntiAfkActive then startAntiAfkLoop() end

print("[VxV Blood Moon Hub] Loaded successfully with direct house paths!")