--========================================================
-- EV03 CONTROL V3.8 - EXECUTOR STANDALONE EDITION
-- Creator: 阿叶ev03
-- 100% 纯客户端本地实现（无需服务端脚本 / 远程事件）
--========================================================

local pcall = pcall
local task = task
local math = math
local table = table
local string = string

pcall(function()
	if getgenv then
		getgenv().EV03_LOADED = true
	end
end)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
if not LP then return end

-- 优先挂载到 CoreGui（若执行器支持），失败则挂载到 PlayerGui
local successGui, targetParent = pcall(function()
	return CoreGui
end)
if not successGui or not targetParent then
	targetParent = LP:WaitForChild("PlayerGui", 10)
end
if not targetParent then return end

--========================================================
-- CLEAN OLD GUI
--========================================================
pcall(function()
	for _, name in ipairs({"EV03_CONTROL", "EV03_ESP"}) do
		local old = targetParent:FindFirstChild(name)
		if old then old:Destroy() end
	end
end)

--========================================================
-- COLORS & HELPERS
--========================================================

local C = {
	BG = Color3.fromRGB(13, 13, 17),
	SIDEBAR = Color3.fromRGB(19, 19, 24),
	PANEL = Color3.fromRGB(26, 26, 33),
	PANEL2 = Color3.fromRGB(36, 36, 44),
	RED = Color3.fromRGB(195, 31, 49),
	DARK_RED = Color3.fromRGB(105, 20, 30),
	GREEN = Color3.fromRGB(27, 155, 76),
	YELLOW = Color3.fromRGB(220, 175, 55),
	WHITE = Color3.fromRGB(245, 245, 245),
	GRAY = Color3.fromRGB(155, 155, 165),
}

local function validNumber(n)
	return typeof(n) == "number"
		and n == n
		and n ~= math.huge
		and n ~= -math.huge
end

local function create(className, props, parent)
	local obj = Instance.new(className)
	pcall(function()
		for key, value in pairs(props or {}) do
			obj[key] = value
		end
	end)
	if parent then
		pcall(function()
			obj.Parent = parent
		end)
	end
	return obj
end

local function getParts(player)
	local ok, char, hum, root = pcall(function()
		if not player or not player.Character then return nil, nil, nil end
		local character = player.Character
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart or humanoid.Health <= 0 then
			return nil, nil, nil
		end
		return character, humanoid, rootPart
	end)
	if not ok then return nil, nil, nil end
	return char, hum, root
end

-- 玩家前缀精准匹配查找
local function findTarget(prefix)
	if typeof(prefix) ~= "string" then
		return nil, "INVALID USERNAME"
	end
	prefix = prefix:match("^%s*(.-)%s*$")
	if not prefix or prefix == "" or #prefix > 20 then
		return nil, "INVALID USERNAME"
	end

	local needle = prefix:lower()
	local exactMatch = nil
	local matches = {}

	pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			local username = player.Name:lower()
			if username == needle then
				exactMatch = player
				break
			end
			if username:sub(1, #needle) == needle then
				table.insert(matches, player)
			end
		end
	end)

	if exactMatch then return exactMatch end
	if #matches == 1 then return matches[1] end
	if #matches == 0 then return nil, "PLAYER NOT FOUND" end

	local names = {}
	for index = 1, math.min(#matches, 5) do
		table.insert(names, matches[index].Name)
	end
	return nil, "MULTIPLE MATCHES: " .. table.concat(names, ", ")
end

--========================================================
-- WINDOW SIZE
--========================================================

local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
local windowWidth = math.floor(math.clamp(viewport.X - 30, 560, 900))
local windowHeight = math.floor(math.clamp(viewport.Y - 40, 440, 680))

--========================================================
-- GUI CREATION
--========================================================

local gui = create("ScreenGui", {
	Name = "EV03_CONTROL",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, targetParent)

local espGui = create("ScreenGui", {
	Name = "EV03_ESP",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, targetParent)

local main = create("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(windowWidth, windowHeight),
	BackgroundColor3 = C.BG,
	BorderSizePixel = 0,
	Active = true,
	ClipsDescendants = true,
}, gui)

create("UICorner", {CornerRadius = UDim.new(0, 11)}, main)
create("UIStroke", {Color = C.RED, Thickness = 2}, main)

--========================================================
-- HEADER
--========================================================

local header = create("Frame", {
	Size = UDim2.new(1, 0, 0, 58),
	BackgroundColor3 = C.SIDEBAR,
	BorderSizePixel = 0,
}, main)

local dragArea = create("TextButton", {
	Size = UDim2.new(1, -110, 1, 0),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Active = true,
}, header)

create("TextLabel", {
	Size = UDim2.new(1, -20, 0, 29),
	Position = UDim2.fromOffset(15, 4),
	BackgroundTransparency = 1,
	Text = "EV03 CONTROL",
	TextColor3 = C.RED,
	TextSize = 23,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
}, dragArea)

create("TextLabel", {
	Size = UDim2.new(1, -20, 0, 15),
	Position = UDim2.fromOffset(16, 34),
	BackgroundTransparency = 1,
	Text = "STANDALONE CLIENT EDITION // V3.8",
	TextColor3 = C.GRAY,
	TextSize = 9,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
}, dragArea)

local function headerButton(text, offset)
	local button = create("TextButton", {
		Size = UDim2.fromOffset(36, 32),
		Position = UDim2.new(1, offset, 0, 13),
		BackgroundColor3 = C.DARK_RED,
		Text = text,
		TextColor3 = C.WHITE,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		BorderSizePixel = 0,
	}, header)
	create("UICorner", {CornerRadius = UDim.new(0, 6)}, button)
	return button
end

local minimizeButton = headerButton("—", -88)
local closeButton = headerButton("×", -45)

--========================================================
-- MAIN BODY & NAVIGATION
--========================================================

local body = create("Frame", {
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.new(1, 0, 1, -86),
	BackgroundTransparency = 1,
}, main)

local sidebar = create("Frame", {
	Size = UDim2.new(0, 158, 1, 0),
	BackgroundColor3 = C.SIDEBAR,
	BorderSizePixel = 0,
}, body)

create("TextLabel", {
	Size = UDim2.new(1, -20, 0, 23),
	Position = UDim2.fromOffset(12, 15),
	BackgroundTransparency = 1,
	Text = "NAVIGATION",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, sidebar)

local navContainer = create("Frame", {
	Position = UDim2.fromOffset(8, 48),
	Size = UDim2.new(1, -16, 0, 370),
	BackgroundTransparency = 1,
}, sidebar)

create("UIListLayout", {Padding = UDim.new(0, 7)}, navContainer)

local contentHost = create("Frame", {
	Position = UDim2.new(0, 158, 0, 0),
	Size = UDim2.new(1, -158, 1, 0),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
}, body)

local footer = create("Frame", {
	Position = UDim2.new(0, 0, 1, -28),
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = C.SIDEBAR,
	BorderSizePixel = 0,
}, main)

local status = create("TextLabel", {
	Size = UDim2.new(1, -24, 1, 0),
	Position = UDim2.fromOffset(12, 0),
	BackgroundTransparency = 1,
	Text = "SYSTEM READY (STANDALONE)",
	TextColor3 = C.GREEN,
	TextSize = 10,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
}, footer)

local function setStatus(message, color)
	pcall(function()
		status.Text = tostring(message)
		status.TextColor3 = color or C.GREEN
	end)
end

--========================================================
-- PAGE BUILDERS
--========================================================

local pages = {}
local navButtons = {}

local function createPage(name)
	local page = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.RED,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Visible = false,
	}, contentHost)

	create("UIPadding", {
		PaddingLeft = UDim.new(0, 13),
		PaddingRight = UDim.new(0, 13),
		PaddingTop = UDim.new(0, 13),
		PaddingBottom = UDim.new(0, 15),
	}, page)

	create("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, page)

	pages[name] = page
	return page
end

local function createSection(parent, title, height)
	local card = create("Frame", {
		Name = title:gsub("%W", "") .. "Section",
		Size = UDim2.new(1, -5, 0, height),
		BackgroundColor3 = C.PANEL,
		BorderSizePixel = 0,
	}, parent)

	create("UICorner", {CornerRadius = UDim.new(0, 9)}, card)
	create("UIStroke", {Color = C.PANEL2, Thickness = 1}, card)

	create("TextLabel", {
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 7),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = C.RED,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	return card
end

local function makeButton(parent, text, x, y, width, height, callback)
	local button = create("TextButton", {
		Size = UDim2.new(width, 0, 0, height),
		Position = UDim2.new(x, 0, 0, y),
		BackgroundColor3 = C.DARK_RED,
		Text = text,
		TextColor3 = C.WHITE,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		BorderSizePixel = 0,
		AutoButtonColor = true,
	}, parent)

	create("UICorner", {CornerRadius = UDim.new(0, 6)}, button)

	button.MouseButton1Click:Connect(function()
		local ok, err = pcall(callback)
		if not ok then
			warn("[EV03 UI ERROR]", err)
			setStatus("LOCAL ACTION ERROR", C.RED)
		end
	end)

	return button
end

local function makeInput(parent, placeholder, x, y, width, height, initial)
	local input = create("TextBox", {
		Size = UDim2.new(width, 0, 0, height),
		Position = UDim2.new(x, 0, 0, y),
		BackgroundColor3 = C.PANEL2,
		TextColor3 = C.WHITE,
		PlaceholderColor3 = C.GRAY,
		PlaceholderText = placeholder,
		Text = initial or "",
		TextSize = 13,
		Font = Enum.Font.Gotham,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, parent)

	create("UICorner", {CornerRadius = UDim.new(0, 6)}, input)
	return input
end

local function makeToggle(parent, title, y, callback)
	local active = false
	local button

	local function setState(value, silent)
		local desired = value == true
		if not silent then
			local ok, result = pcall(callback, desired)
			if not ok then
				warn("[EV03 TOGGLE ERROR]", result)
				desired = false
			elseif result == false then
				desired = false
			end
		end
		active = desired
		button.Text = title .. (active and "  //  ON" or "  //  OFF")
		button.BackgroundColor3 = active and C.GREEN or C.DARK_RED
		return active
	end

	button = makeButton(parent, title .. "  //  OFF", 0, y, 1, 38, function()
		setState(not active)
	end)

	return button, setState
end

local function addNavigation(name, label, symbol)
	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = C.SIDEBAR,
		Text = symbol .. "   " .. label,
		TextColor3 = C.GRAY,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		BorderSizePixel = 0,
	}, navContainer)

	create("UICorner", {CornerRadius = UDim.new(0, 6)}, button)
	navButtons[name] = button

	button.MouseButton1Click:Connect(function()
		for pageName, page in pairs(pages) do
			page.Visible = pageName == name
		end
		for pageName, nav in pairs(navButtons) do
			local selected = pageName == name
			nav.BackgroundColor3 = selected and C.DARK_RED or C.SIDEBAR
			nav.TextColor3 = selected and C.WHITE or C.GRAY
		end
		setStatus("PAGE: " .. name)
	end)

	return button
end

--========================================================
-- PAGES DEFINITION
--========================================================

local dashboardPage = createPage("DASHBOARD")
local playerPage = createPage("PLAYER")
local movementPage = createPage("MOVEMENT")
local espPage = createPage("ESP")
local hotkeyPage = createPage("HOTKEYS")
local aboutPage = createPage("ABOUT")

addNavigation("DASHBOARD", "Dashboard", "◆")
addNavigation("PLAYER", "Player", "◈")
addNavigation("MOVEMENT", "Movement", "↗")
addNavigation("ESP", "ESP System", "◎")
addNavigation("HOTKEYS", "Hotkeys", "⌨")
addNavigation("ABOUT", "About", "ⓘ")

--========================================================
-- CORE FEATURES: 纯客户端本地实现 (NOCLIP, INVISIBLE, FLING, TELEPORT)
--========================================================

-- 1. NOCLIP (穿墙) 本地实现
local noclipConnection = nil
local noclipActive = false

local function setLocalNoclip(state)
	noclipActive = state
	pcall(function()
		if noclipConnection then
			noclipConnection:Disconnect()
			noclipConnection = nil
		end
	end)

	if state then
		noclipConnection = RunService.Stepped:Connect(function()
			pcall(function()
				local char = LP.Character
				if char then
					for _, part in ipairs(char:GetDescendants()) do
						if part:IsA("BasePart") then
							part.CanCollide = false
						end
					end
				end
			end)
		end)
		setStatus("NOCLIP ENABLED (LOCAL)", C.GREEN)
	else
		setStatus("NOCLIP DISABLED", C.RED)
	end
	return true
end

-- 2. INVISIBLE (隐身) 本地实现
local invisibleActive = false
local function setLocalInvisible(state)
	invisibleActive = state
	pcall(function()
		local char = LP.Character
		if not char then return end
		for _, obj in ipairs(char:GetDescendants()) do
			if obj:IsA("BasePart") or obj:IsA("Decal") then
				obj.Transparency = state and 1 or 0
			end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = state and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
		end
	end)
	setStatus(state and "INVISIBILITY ENABLED (LOCAL)" or "INVISIBILITY DISABLED", state and C.GREEN or C.RED)
	return true
end

-- 3. TELEPORT (指定玩家传送) 本地实现
local function localTeleportToTarget(targetName)
	local target, err = findTarget(targetName)
	if not target then
		setStatus(err or "PLAYER NOT FOUND", C.RED)
		return
	end
	if target == LP then
		setStatus("CANNOT TARGET YOURSELF", C.RED)
		return
	end

	pcall(function()
		local _, _, myRoot = getParts(LP)
		local targetChar, _, targetRoot = getParts(target)
		if myRoot and targetChar and targetRoot then
			myRoot.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 3)
			setStatus("TELEPORTED TO: " .. target.Name, C.GREEN)
		else
			setStatus("CHARACTER NOT READY", C.RED)
		end
	end)
end

-- 4. FLING (甩飞) 客户端本地物理冲撞与绕转模拟实现（对标服务端逻辑）
local function localFlingTarget(targetName, power)
	local target, err = findTarget(targetName)
	if not target then
		setStatus(err or "PLAYER NOT FOUND", C.RED)
		return
	end
	if target == LP then
		setStatus("CANNOT TARGET YOURSELF", C.RED)
		return
	end

	pcall(function()
		local _, _, myRoot = getParts(LP)
		local targetChar, _, targetRoot = getParts(target)
		if not myRoot or not targetRoot then
			setStatus("CHARACTER NOT READY", C.RED)
			return
		end

		task.spawn(function()
			local oldPos = myRoot.CFrame
			local speed = 15000 * (power or 5)
			local elapsed = 0
			
			local connection
			connection = RunService.Heartbeat:Connect(function(dt)
				elapsed = elapsed + dt
				pcall(function()
					if targetRoot and targetRoot.Parent and myRoot and myRoot.Parent then
						myRoot.CFrame = targetRoot.CFrame
						myRoot.AssemblyLinearVelocity = Vector3.new(math.random(-speed, speed), speed, math.random(-speed, speed))
						myRoot.AssemblyAngularVelocity = Vector3.new(speed, speed, speed)
					end
				end)
				if elapsed > 0.4 then
					connection:Disconnect()
					pcall(function()
						if myRoot and myRoot.Parent then
							myRoot.CFrame = oldPos
							myRoot.AssemblyLinearVelocity = Vector3.zero
							myRoot.AssemblyAngularVelocity = Vector3.zero
						end
					end)
				end
			end)
			setStatus("FLING STARTED ON: " .. target.Name, C.GREEN)
		end)
	end)
end

local function localFlingAll(power)
	pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LP then
				localFlingTarget(player.Name, power)
			end
		end
		setStatus("FLING ALL EXECUTED", C.GREEN)
	end)
end

--========================================================
-- DASHBOARD
--========================================================

local dashboardCard = createSection(dashboardPage, "EV03 // DASHBOARD", 160)
create("TextLabel", {
	Size = UDim2.new(1, -28, 0, 35),
	Position = UDim2.fromOffset(14, 40),
	BackgroundTransparency = 1,
	Text = "WELCOME TO EV03 CONTROL (STANDALONE)",
	TextColor3 = C.WHITE,
	TextSize = 17,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
}, dashboardCard)

create("TextLabel", {
	Size = UDim2.new(1, -28, 0, 70),
	Position = UDim2.fromOffset(14, 82),
	BackgroundTransparency = 1,
	Text = "Creator: 阿叶ev03\nVersion: V3.8\nStandalone Executor Edition (No Server Required)",
	TextColor3 = C.GRAY,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, dashboardCard)

--========================================================
-- PLAYER PAGE
--========================================================

local playerCard = createSection(playerPage, "PLAYER // MANAGEMENT", 205)
local targetInput = makeInput(playerCard, "Enter exact Roblox Username...", 0, 39, 1, 36, "")

create("TextLabel", {
	Size = UDim2.new(0.28, -6, 0, 28),
	Position = UDim2.fromOffset(0, 83),
	BackgroundTransparency = 1,
	Text = "甩飞力道 (1-10)",
	TextColor3 = C.GRAY,
	TextSize = 11,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, playerCard)

local flingPowerInput = makeInput(playerCard, "1-10", 0.29, 82, 0.23, 32, "10")

create("TextLabel", {
	Size = UDim2.new(0.68, -6, 0, 30),
	Position = UDim2.new(0.53, 6, 0, 83),
	BackgroundTransparency = 1,
	Text = "数值越大，本地物理甩飞强度越高",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
}, playerCard)

local function getTarget()
	local name = targetInput.Text:match("^%s*(.-)%s*$")
	if not name or name == "" then
		setStatus("PLEASE ENTER USERNAME", C.RED)
		return nil
	end
	return name
end

local function getFlingPower()
	local power = tonumber(flingPowerInput.Text)
	if not validNumber(power) or power < 1 or power > 10 then
		setStatus("甩飞力道必须是 1 到 10", C.RED)
		return nil
	end
	return math.floor(power + 0.5)
end

makeButton(playerCard, "TELEPORT TO ME", 0, 145, 0.32, 40, function()
	local name = getTarget()
	if name then localTeleportToTarget(name) end
end)

makeButton(playerCard, "FLING TARGET", 0.34, 145, 0.32, 40, function()
	local name = getTarget()
	local power = getFlingPower()
	if name and power then localFlingTarget(name, power) end
end)

makeButton(playerCard, "FLING ALL", 0.68, 145, 0.32, 40, function()
	local power = getFlingPower()
	if power then localFlingAll(power) end
end)

--========================================================
-- MOVEMENT PAGE
--========================================================

local movementCard = createSection(movementPage, "MOVEMENT // CAMERA FLY / SPEED / NOCLIP", 365)

local infiniteJump = false
local flyEnabled = false
local flySpeed = 80

makeToggle(movementCard, "INFINITE JUMP", 42, function(state)
	infiniteJump = state
	return true
end)

local walkInput = makeInput(movementCard, "Walk speed (finite number)", 0, 91, 0.62, 36, "32")
makeButton(movementCard, "APPLY WALK SPEED", 0.65, 91, 0.35, 36, function()
	local speed = tonumber(walkInput.Text)
	if not validNumber(speed) or speed < 0 then
		setStatus("INVALID WALK SPEED", C.RED)
		return
	end
	pcall(function()
		local _, hum = getParts(LP)
		if hum then hum.WalkSpeed = speed end
	end)
	setStatus("WALK SPEED: " .. tostring(speed), C.GREEN)
end)

local flyInput = makeInput(movementCard, "Fly speed (finite number)", 0, 141, 0.62, 36, "80")
makeButton(movementCard, "APPLY FLY SPEED", 0.65, 141, 0.35, 36, function()
	local speed = tonumber(flyInput.Text)
	if not validNumber(speed) or speed < 0 then
		setStatus("INVALID FLY SPEED", C.RED)
		return
	end
	flySpeed = speed
	setStatus("FLY SPEED: " .. tostring(speed), C.GREEN)
end)

-- CAMERA FLY ENGINE
local flyAttachment, flyVelocity, flyOrientation, flyConnection, flyHumanoid, oldAutoRotate

local function cleanupFly()
	pcall(function()
		if flyConnection then flyConnection:Disconnect() flyConnection = nil end
		if flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
		if flyOrientation then flyOrientation:Destroy() flyOrientation = nil end
		if flyAttachment then flyAttachment:Destroy() flyAttachment = nil end
		local _, hum = getParts(LP)
		if hum then
			if oldAutoRotate ~= nil then hum.AutoRotate = oldAutoRotate end
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
	flyHumanoid = nil
	oldAutoRotate = nil
end

local function setupFly()
	cleanupFly()
	local char, humanoid, root = getParts(LP)
	if not char or not humanoid or not root then return false end

	local ok = pcall(function()
		flyAttachment = create("Attachment", {Name = "EV03_FlyAttachment"}, root)
		flyVelocity = create("LinearVelocity", {
			Name = "EV03_FlyVelocity",
			Attachment0 = flyAttachment,
			RelativeTo = Enum.ActuatorRelativeTo.World,
			VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
			ForceLimitsEnabled = false,
			VectorVelocity = Vector3.zero,
		}, root)

		flyOrientation = create("AlignOrientation", {
			Name = "EV03_FlyOrientation",
			Mode = Enum.OrientationAlignmentMode.OneAttachment,
			Attachment0 = flyAttachment,
			RigidityEnabled = true,
			Responsiveness = 200,
			MaxTorque = 1000000000,
		}, root)

		flyHumanoid = humanoid
		oldAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end)

	if not ok then cleanupFly() return false end

	flyConnection = RunService.PreSimulation:Connect(function()
		if not flyEnabled then return end
		pcall(function()
			local currentCamera = workspace.CurrentCamera
			if not currentCamera or not root.Parent then return end
			local cf = currentCamera.CFrame
			local move = Vector3.zero
			if not UIS:GetFocusedTextBox() then
				if UIS:IsKeyDown(Enum.KeyCode.W) then move += cf.LookVector end
				if UIS:IsKeyDown(Enum.KeyCode.S) then move -= cf.LookVector end
				if UIS:IsKeyDown(Enum.KeyCode.A) then move -= cf.RightVector end
				if UIS:IsKeyDown(Enum.KeyCode.D) then move += cf.RightVector end
				if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
				if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl) then move -= Vector3.yAxis end
			end
			if move.Magnitude > 1 then move = move.Unit end
			if flyVelocity then flyVelocity.VectorVelocity = move * flySpeed end
		end)
	end)
	return true
end

makeToggle(movementCard, "CAMERA FLY", 191, function(state)
	flyEnabled = state
	if state then
		if not setupFly() then
			flyEnabled = false
			setStatus("FLY INIT FAILED", C.RED)
			return false
		end
		setStatus("CAMERA FLY ENABLED", C.GREEN)
	else
		cleanupFly()
		setStatus("FLY DISABLED", C.RED)
	end
	return true
end)

makeToggle(movementCard, "NOCLIP / 穿墙", 241, function(state)
	return setLocalNoclip(state)
end)

makeToggle(movementCard, "INVISIBILITY / 隐身", 291, function(state)
	return setLocalInvisible(state)
end)

UIS.JumpRequest:Connect(function()
	if not infiniteJump then return end
	pcall(function()
		local _, hum = getParts(LP)
		if hum and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
end)

--========================================================
-- ESP SYSTEM
--========================================================

local espCard = createSection(espPage, "ESP // VISUAL SYSTEM", 145)
local espEnabled = false
local espObjects = {}

local function cleanupESP(data)
	if not data then return end
	pcall(function()
		for _, c in ipairs(data.connections or {}) do c:Disconnect() end
		for _, o in ipairs(data.objects or {}) do o:Destroy() end
	end)
end

local function removeESP(player)
	if espObjects[player] then
		cleanupESP(espObjects[player])
		espObjects[player] = nil
	end
end

local function createESP(player)
	if not espEnabled or player == LP then return end
	removeESP(player)

	pcall(function()
		local char, hum, root = getParts(player)
		if not char or not hum or not root then return end

		local objects = {}
		local connections = {}

		local highlight = create("Highlight", {
			Adornee = char,
			FillColor = C.RED,
			OutlineColor = C.WHITE,
			FillTransparency = 0.82,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		}, char)
		table.insert(objects, highlight)

		local billboard = create("BillboardGui", {
			Adornee = root,
			Size = UDim2.fromOffset(140, 40),
			StudsOffset = Vector3.new(0, 4, 0),
			AlwaysOnTop = true,
		}, espGui)
		table.insert(objects, billboard)

		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = player.Name,
			TextColor3 = C.WHITE,
			TextStrokeTransparency = 0.2,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
		}, billboard)

		espObjects[player] = {objects = objects, connections = connections}
	end)
end

makeToggle(espCard, "PLAYER ESP", 42, function(state)
	espEnabled = state
	if not state then
		for player in pairs(espObjects) do removeESP(player) end
	else
		for _, player in ipairs(Players:GetPlayers()) do createESP(player) end
	end
	return true
end)

create("TextLabel", {
	Size = UDim2.new(1, -24, 0, 25),
	Position = UDim2.fromOffset(12, 91),
	BackgroundTransparency = 1,
	Text = "HIGHLIGHT / NAME ESP (LOCAL)",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
}, espCard)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if espEnabled then createESP(player) end
	end)
end)
Players.PlayerRemoving:Connect(removeESP)

--========================================================
-- HOTKEYS & HANDLERS
--========================================================

local handlers = {}
handlers.InfiniteJump = function() infiniteJump = not infiniteJump end
handlers.Fly = function() flyEnabled = not flyEnabled end
handlers.Noclip = function() setLocalNoclip(not noclipActive) end
handlers.Invisible = function() setLocalInvisible(not invisibleActive) end
handlers.ToggleMenu = function() gui.Enabled = not gui.Enabled end
handlers.Panic = function()
	flyEnabled = false
	cleanupFly()
	setLocalNoclip(false)
	setLocalInvisible(false)
	espEnabled = false
	for player in pairs(espObjects) do removeESP(player) end
	pcall(function()
		local _, hum = getParts(LP)
		if hum then hum.WalkSpeed = 16 end
	end)
	setStatus("PANIC RESET COMPLETE", C.RED)
end

local hotkeyCard = createSection(hotkeyPage, "HOTKEYS // 快捷键分组", 605)
create("TextLabel", {
	Size = UDim2.new(1, -24, 0, 35),
	Position = UDim2.fromOffset(12, 37),
	BackgroundTransparency = 1,
	Text = "点击右侧按钮，再按下想绑定的新按键。",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
}, hotkeyCard)

local bindings = {
	InfiniteJump = Enum.KeyCode.J,
	Fly = Enum.KeyCode.F,
	Noclip = Enum.KeyCode.N,
	Invisible = Enum.KeyCode.V,
	Panic = Enum.KeyCode.P,
	ToggleMenu = Enum.KeyCode.RightShift,
}

local bindingRows = {
	{"InfiniteJump", "无限跳跃"},
	{"Fly", "摄像机飞行开关"},
	{"Noclip", "穿墙开关"},
	{"Invisible", "隐身开关"},
	{"Panic", "Panic 重置"},
	{"ToggleMenu", "菜单显示 / 隐藏"},
}

local bindButtons = {}
local listeningAction = nil

local function refreshBindingLabels()
	for action, button in pairs(bindButtons) do
		pcall(function()
			button.Text = bindings[action] and bindings[action].Name or "UNBOUND"
		end)
	end
end

local rowStart = 82
local rowSpacing = 39

for index, row in ipairs(bindingRows) do
	local action = row[1]
	local label = row[2]
	local y = rowStart + (index - 1) * rowSpacing

	create("TextLabel", {
		Size = UDim2.new(0.59, -5, 0, 32),
		Position = UDim2.fromOffset(12, y),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = C.WHITE,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, hotkeyCard)

	local bindButton
	bindButton = makeButton(hotkeyCard, bindings[action].Name, 0.63, y, 0.34, 32, function()
		listeningAction = action
		bindButton.Text = "PRESS KEY..."
		setStatus("REBINDING: " .. label, C.YELLOW)
	end)
	bindButtons[action] = bindButton
end

makeButton(hotkeyCard, "PANIC // DISABLE ALL", 0, 555, 1, 30, handlers.Panic)

--========================================================
-- ABOUT PAGE
--========================================================

local aboutCard = createSection(aboutPage, "ABOUT // 身份组", 285)
create("TextLabel", {
	Size = UDim2.new(1, -32, 0, 225),
	Position = UDim2.fromOffset(16, 42),
	BackgroundTransparency = 1,
	Text = table.concat({
		"PROJECT INFORMATION",
		"",
		"项目名称：EV03 CONTROL",
		"项目版本：V3.8",
		"运行模式：Executor Standalone (纯客户端版)",
		"",
		"CREATOR IDENTITY",
		"",
		"创作者：阿叶ev03",
		"身份：Creator / Developer",
	}, "\n"),
	TextColor3 = C.WHITE,
	TextSize = 12,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
}, aboutCard)

--========================================================
-- DRAG & INPUT HANDLING
--========================================================

local dragging = false
local dragStart, startPosition, dragInput

dragArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPosition = main.Position
	end
end)

UIS.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
	if dragging and dragInput then
		local delta = dragInput.Position - dragStart
		main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local minimized = false
local originalSize = main.Size

minimizeButton.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		originalSize = main.Size
		body.Visible = false
		footer.Visible = false
		main.Size = UDim2.fromOffset(windowWidth, 58)
		minimizeButton.Text = "+"
	else
		main.Size = originalSize
		body.Visible = true
		footer.Visible = true
		minimizeButton.Text = "—"
	end
end)

closeButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

UIS.InputBegan:Connect(function(input, processed)
	if listeningAction then
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode == Enum.KeyCode.Escape then
			listeningAction = nil
			refreshBindingLabels()
			setStatus("BINDING CANCELLED", C.YELLOW)
			return
		end
		local action = listeningAction
		listeningAction = nil
		bindings[action] = input.KeyCode
		refreshBindingLabels()
		setStatus(action .. " KEY: " .. input.KeyCode.Name, C.GREEN)
		return
	end

	if input.UserInputType ~= Enum.UserInputType.Keyboard or processed or UIS:GetFocusedTextBox() then return end

	for action, key in pairs(bindings) do
		if key and key == input.KeyCode then
			local handler = handlers[action]
			if handler then pcall(handler) end
			return
		end
	end
end)

--========================================================
-- INITIALIZATION & READY
--========================================================

refreshBindingLabels()
pcall(function()
	pages["DASHBOARD"].Visible = true
	navButtons["DASHBOARD"].BackgroundColor3 = C.DARK_RED
	navButtons["DASHBOARD"].TextColor3 = C.WHITE
end)

setStatus("EV03 STANDALONE V3.8 READY", C.GREEN)
print("[EV03 CONTROL V3.8] EXECUTOR STANDALONE EDITION LOADED SUCCESSFULLY.")
