--========================================================
-- EV03 CONTROL V3.8 - EXECUTOR STANDALONE EDITION
-- CAMERA DIRECTION FLIGHT + PREFIX TARGETING (CLIENT ONLY)
-- Creator: 阿叶ev03
-- Compatibility: Xeno / Synapse / Fluxus / Wave / Solara
--========================================================

if not game:IsLoaded() then
	pcall(function()
		game.Loaded:Wait()
	end)
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
while not LP do
	task.wait(0.1)
	LP = Players.LocalPlayer
end

local function getGuiParent()
	local ok, hui = pcall(function()
		if type(gethui) == "function" then
			return gethui()
		end
		return nil
	end)
	if ok and typeof(hui) == "Instance" then
		return hui
	end

	local coreOk = pcall(function()
		local _ = CoreGui.Name
	end)
	if coreOk and CoreGui then
		return CoreGui
	end

	return LP:WaitForChild("PlayerGui", 15)
end

local GUI_PARENT = getGuiParent()
if not GUI_PARENT then
	warn("[EV03] FAILED TO RESOLVE GUI PARENT")
	return
end

--========================================================
-- CLEAN OLD INSTANCE & CONNECTIONS
--========================================================

pcall(function()
	if getgenv and type(getgenv) == "function" then
		local env = getgenv()
		if env.EV03_CLEANUP and type(env.EV03_CLEANUP) == "function" then
			pcall(env.EV03_CLEANUP)
		end
	end
end)

for _, targetParent in ipairs({GUI_PARENT, LP:FindFirstChild("PlayerGui")}) do
	if targetParent then
		for _, name in ipairs({"EV03_CONTROL", "EV03_ESP"}) do
			local old = targetParent:FindFirstChild(name)
			if old then
				pcall(function()
					old:Destroy()
				end)
			end
		end
	end
end

--========================================================
-- CONNECTION MANAGER & SAFE HELPERS
--========================================================

local activeConnections = {}

local function trackConnection(conn)
	if conn then
		table.insert(activeConnections, conn)
	end
	return conn
end

local function validNumber(n)
	return typeof(n) == "number"
		and n == n
		and n ~= math.huge
		and n ~= -math.huge
end

local function create(className, props, parent)
	local ok, obj = pcall(function()
		return Instance.new(className)
	end)
	if not ok or not obj then
		return nil
	end

	for key, value in pairs(props or {}) do
		pcall(function()
			obj[key] = value
		end)
	end

	pcall(function()
		obj.Parent = parent
	end)
	return obj
end

local function getParts(player)
	local targetPlayer = player or LP
	if not targetPlayer then
		return nil, nil, nil
	end

	local character = targetPlayer.Character
	if not character or not character.Parent then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	return character, humanoid, root
end

--========================================================
-- COLORS
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

--========================================================
-- WINDOW SIZE
--========================================================

local camera = workspace.CurrentCamera
local viewport = (camera and camera.ViewportSize) or Vector2.new(1280, 720)

local windowWidth = math.floor(math.clamp(viewport.X - 30, 560, 900))
local windowHeight = math.floor(math.clamp(viewport.Y - 40, 440, 680))

--========================================================
-- GUI
--========================================================

local gui = create("ScreenGui", {
	Name = "EV03_CONTROL",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, GUI_PARENT)

local espGui = create("ScreenGui", {
	Name = "EV03_ESP",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, GUI_PARENT)

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
	Text = "STANDALONE EXECUTOR EDITION // V3.8",
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
-- MAIN BODY
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
	Text = "STANDALONE SYSTEM READY",
	TextColor3 = C.GREEN,
	TextSize = 10,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
}, footer)

local function setStatus(message, color)
	pcall(function()
		if status and status.Parent then
			status.Text = tostring(message)
			status.TextColor3 = color or C.GREEN
		end
	end)
end

--========================================================
-- PAGE SYSTEM
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

--========================================================
-- BUTTON & TOGGLE HELPERS
--========================================================

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

	if button then
		trackConnection(button.MouseButton1Click:Connect(function()
			local ok, err = pcall(callback)
			if not ok then
				warn("[EV03 UI ERROR]", err)
				setStatus("LOCAL ACTION ERROR", C.RED)
			end
		end))
	end

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
		pcall(function()
			if button and button.Parent then
				button.Text = title .. (active and "  //  ON" or "  //  OFF")
				button.BackgroundColor3 = active and C.GREEN or C.DARK_RED
			end
		end)
		return active
	end

	button = makeButton(parent, title .. "  //  OFF", 0, y, 1, 38, function()
		setState(not active)
	end)

	return button, setState
end

--========================================================
-- NAVIGATION
--========================================================

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

	if button then
		trackConnection(button.MouseButton1Click:Connect(function()
			pcall(function()
				for pageName, page in pairs(pages) do
					if page then
						page.Visible = (pageName == name)
					end
				end

				for pageName, nav in pairs(navButtons) do
					if nav then
						local selected = (pageName == name)
						nav.BackgroundColor3 = selected and C.DARK_RED or C.SIDEBAR
						nav.TextColor3 = selected and C.WHITE or C.GRAY
					end
				end

				setStatus("PAGE: " .. name)
			end)
		end))
	end

	return button
end

--========================================================
-- PAGES
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
-- SHARED STATES
--========================================================

local infiniteJump = false
local flyEnabled = false
local noclipEnabled = false
local invisibleEnabled = false
local espEnabled = false
local flySpeed = 80
local customWalkSpeed = nil
local isFlinging = false

local setJumpState
local setFlyState
local setNoclipState
local setInvisibleState
local setESPState

--========================================================
-- DASHBOARD
--========================================================

local dashboardCard = createSection(dashboardPage, "EV03 // DASHBOARD", 160)

create("TextLabel", {
	Size = UDim2.new(1, -28, 0, 35),
	Position = UDim2.fromOffset(14, 40),
	BackgroundTransparency = 1,
	Text = "WELCOME TO EV03 CONTROL",
	TextColor3 = C.WHITE,
	TextSize = 19,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
}, dashboardCard)

create("TextLabel", {
	Size = UDim2.new(1, -28, 0, 70),
	Position = UDim2.fromOffset(14, 82),
	BackgroundTransparency = 1,
	Text = "Creator: 阿叶ev03\nVersion: V3.8 (Executor Standalone)\nCamera Direction Flight + Local Physics Engine",
	TextColor3 = C.GRAY,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, dashboardCard)

--========================================================
-- PLAYER PAGE & LOCAL TARGETING / TELEPORT / FLING
--========================================================

local playerCard = createSection(playerPage, "PLAYER // MANAGEMENT", 160)
local targetInput = makeInput(
	playerCard,
	"Enter Username or Prefix...",
	0, 39, 1, 36, ""
)

local function findTarget(prefix)
	if typeof(prefix) ~= "string" then
		return nil, "INVALID USERNAME"
	end

	prefix = prefix:match("^%s*(.-)%s*$")
	if not prefix or prefix == "" or #prefix > 20 then
		return nil, "PLEASE ENTER USERNAME"
	end

	local needle = prefix:lower()
	local exactMatch = nil
	local matches = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LP then
			local username = player.Name:lower()
			local displayName = (player.DisplayName or ""):lower()

			if username == needle or displayName == needle then
				exactMatch = player
				break
			end

			if username:sub(1, #needle) == needle or displayName:sub(1, #needle) == needle then
				table.insert(matches, player)
			end
		end
	end

	if exactMatch then
		return exactMatch
	end

	if #matches == 1 then
		return matches[1]
	end

	if #matches == 0 then
		return nil, "PLAYER NOT FOUND"
	end

	local names = {}
	for index = 1, math.min(#matches, 5) do
		table.insert(names, matches[index].Name)
	end

	local suffix = #matches > 5 and " ..." or ""
	return nil, "MULTIPLE MATCHES: " .. table.concat(names, ", ") .. suffix
end

local function teleportToTarget()
	local name = targetInput and targetInput.Text or ""
	local target, findError = findTarget(name)
	if not target then
		setStatus(findError or "PLAYER NOT FOUND", C.RED)
		return
	end

	local myChar, _, myRoot = getParts(LP)
	local _, _, targetRoot = getParts(target)

	if not myChar or not myRoot or not targetRoot then
		setStatus("CHARACTER NOT READY", C.RED)
		return
	end

	local ok = pcall(function()
		myChar:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, 3.5))
		myRoot.AssemblyLinearVelocity = Vector3.zero
		myRoot.AssemblyAngularVelocity = Vector3.zero
	end)

	if ok then
		setStatus("TELEPORTED TO: " .. target.Name, C.GREEN)
	else
		setStatus("TELEPORT FAILED", C.RED)
	end
end

-- Client-side Rotational Collision Fling (Network Ownership Impulse)
local function executeClientFling(targetList, label)
	if isFlinging then
		setStatus("FLING ALREADY RUNNING", C.YELLOW)
		return
	end

	local myChar, myHum, myRoot = getParts(LP)
	if not myChar or not myHum or not myRoot then
		setStatus("CHARACTER NOT READY", C.RED)
		return
	end

	if #targetList == 0 then
		setStatus("NO VALID TARGETS", C.RED)
		return
	end

	isFlinging = true
	setStatus("FLINGING: " .. label, C.YELLOW)

	task.spawn(function()
		local savedPivot = myChar:GetPivot()
		local oldPlatformStand = myHum.PlatformStand
		local oldCollideStates = {}

		for _, part in ipairs(myChar:GetDescendants()) do
			if part:IsA("BasePart") then
				oldCollideStates[part] = part.CanCollide
			end
		end

		local flingConn
		pcall(function()
			myHum.PlatformStand = true
			flingConn = RunService.Heartbeat:Connect(function()
				if not myChar or not myChar.Parent or not myRoot or not myRoot.Parent then
					return
				end
				for _, part in ipairs(myChar:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = true
					end
				end
				myRoot.AssemblyAngularVelocity = Vector3.new(0, 99999, 0)
				myRoot.AssemblyLinearVelocity = Vector3.new(0, 15, 0)
			end)
		end)

		local affected = 0
		for _, target in ipairs(targetList) do
			if not isFlinging then break end
			local _, targetHum, targetRoot = getParts(target)
			if targetHum and targetRoot and not targetHum.Sit then
				affected += 1
				local startTime = os.clock()
				local duration = (#targetList == 1) and 1.25 or 0.55

				while isFlinging and (os.clock() - startTime) < duration do
					if not myRoot or not myRoot.Parent or not targetRoot or not targetRoot.Parent then
						break
					end
					pcall(function()
						local predOffset = targetRoot.AssemblyLinearVelocity * 0.12
						local jitter = Vector3.new(
							math.random(-2, 2) * 0.6,
							math.random(-1, 2) * 0.5,
							math.random(-2, 2) * 0.6
						)
						myRoot.CFrame = CFrame.new(targetRoot.Position + predOffset + jitter)
							* CFrame.Angles(
								math.rad(math.random(0, 360)),
								math.rad(math.random(0, 360)),
								math.rad(math.random(0, 360))
							)
					end)
					RunService.Heartbeat:Wait()
				end
			end
		end

		if flingConn then
			pcall(function()
				flingConn:Disconnect()
			end)
		end

		pcall(function()
			if myRoot and myRoot.Parent then
				myRoot.AssemblyLinearVelocity = Vector3.zero
				myRoot.AssemblyAngularVelocity = Vector3.zero
			end
			if myChar and myChar.Parent then
				myChar:PivotTo(savedPivot)
			end
			if myHum and myHum.Parent then
				myHum.PlatformStand = oldPlatformStand
				myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			for part, canCol in pairs(oldCollideStates) do
				if part and part.Parent then
					part.CanCollide = canCol
				end
			end
		end)

		isFlinging = false
		if affected > 0 then
			setStatus("FLING COMPLETE (" .. tostring(affected) .. ")", C.GREEN)
		else
			setStatus("TARGET SITTING OR UNREACHABLE", C.RED)
		end
	end)
end

local function flingTarget()
	local name = targetInput and targetInput.Text or ""
	local target, findError = findTarget(name)
	if not target then
		setStatus(findError or "PLAYER NOT FOUND", C.RED)
		return
	end
	executeClientFling({target}, target.Name)
end

local function flingAll()
	local targets = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LP then
			table.insert(targets, player)
		end
	end
	executeClientFling(targets, "ALL PLAYERS")
end

makeButton(playerCard, "TELEPORT TO TARGET", 0, 88, 0.32, 40, teleportToTarget)
makeButton(playerCard, "FLING TARGET", 0.34, 88, 0.32, 40, flingTarget)
makeButton(playerCard, "FLING ALL", 0.68, 88, 0.32, 40, flingAll)

--========================================================
-- MOVEMENT PAGE (LOCAL SPEED / NOCLIP / INVISIBLE)
--========================================================

local movementCard = createSection(
	movementPage,
	"MOVEMENT // CAMERA FLY / SPEED / NOCLIP",
	365
)

local jumpButton
jumpButton, setJumpState = makeToggle(movementCard, "INFINITE JUMP", 42, function(state)
	infiniteJump = state
	setStatus(state and "INFINITE JUMP ENABLED" or "INFINITE JUMP DISABLED", state and C.GREEN or C.RED)
	return true
end)

local walkInput = makeInput(
	movementCard,
	"Walk speed (finite number)",
	0, 91, 0.62, 36, "32"
)

local function applyWalkSpeed()
	local speed = tonumber(walkInput and walkInput.Text)
	if not validNumber(speed) or speed < 0 or speed > 1000 then
		setStatus("INVALID WALK SPEED (0-1000)", C.RED)
		return
	end

	customWalkSpeed = speed
	local _, humanoid = getParts(LP)
	if humanoid then
		local ok = pcall(function()
			humanoid.WalkSpeed = speed
		end)
		if ok then
			setStatus("WALK SPEED: " .. tostring(speed), C.GREEN)
		else
			setStatus("WALK SPEED SET FAILED", C.RED)
		end
	else
		setStatus("WALK SPEED QUEUED: " .. tostring(speed), C.YELLOW)
	end
end

makeButton(movementCard, "APPLY WALK SPEED", 0.65, 91, 0.35, 36, applyWalkSpeed)

local flyInput = makeInput(
	movementCard,
	"Fly speed (finite number)",
	0, 141, 0.62, 36, "80"
)

local function applyFlySpeed()
	local speed = tonumber(flyInput and flyInput.Text)
	if not validNumber(speed) or speed < 0 or speed > 2000 then
		setStatus("INVALID FLY SPEED", C.RED)
		return
	end
	flySpeed = speed
	setStatus("FLY SPEED: " .. tostring(speed), C.GREEN)
end

makeButton(movementCard, "APPLY FLY SPEED", 0.65, 141, 0.35, 36, applyFlySpeed)

--========================================================
-- CAMERA DIRECTION FLY ENGINE
--========================================================

local flyAttachment
local flyVelocity
local flyOrientation
local flyConnection
local flyHumanoid
local oldAutoRotate

local function cleanupFly()
	if flyConnection then
		pcall(function()
			flyConnection:Disconnect()
		end)
		flyConnection = nil
	end

	for _, object in ipairs({flyVelocity, flyOrientation, flyAttachment}) do
		if object then
			pcall(function()
				object:Destroy()
			end)
		end
	end

	flyVelocity = nil
	flyOrientation = nil
	flyAttachment = nil

	if flyHumanoid and flyHumanoid.Parent then
		pcall(function()
			if oldAutoRotate ~= nil then
				flyHumanoid.AutoRotate = oldAutoRotate
			end
			if flyHumanoid.Health > 0 then
				flyHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end

	flyHumanoid = nil
	oldAutoRotate = nil
end

local function getBodyForward(root, cameraCFrame)
	local look = cameraCFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)

	if flat.Magnitude < 0.001 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end

	if flat.Magnitude < 0.001 then
		flat = Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function setupFly()
	cleanupFly()

	local character = LP.Character
	if not character then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	local success = pcall(function()
		root.AssemblyAngularVelocity = Vector3.zero

		flyAttachment = Instance.new("Attachment")
		flyAttachment.Name = "EV03_FlyAttachment"
		flyAttachment.Parent = root

		flyVelocity = Instance.new("LinearVelocity")
		flyVelocity.Name = "EV03_FlyVelocity"
		flyVelocity.Attachment0 = flyAttachment
		flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		flyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		flyVelocity.ForceLimitsEnabled = false
		flyVelocity.VectorVelocity = Vector3.zero
		flyVelocity.Parent = root

		flyOrientation = Instance.new("AlignOrientation")
		flyOrientation.Name = "EV03_FlyOrientation"
		flyOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		flyOrientation.Attachment0 = flyAttachment
		flyOrientation.RigidityEnabled = true
		flyOrientation.Responsiveness = 200
		flyOrientation.MaxTorque = 1000000000
		flyOrientation.MaxAngularVelocity = 1000000

		local cam = workspace.CurrentCamera
		local bodyForward = getBodyForward(root, cam and cam.CFrame or root.CFrame)
		flyOrientation.CFrame = CFrame.lookAt(Vector3.zero, bodyForward, Vector3.yAxis)
		flyOrientation.Parent = root

		flyHumanoid = humanoid
		oldAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end)

	if not success then
		cleanupFly()
		return false
	end

	flyConnection = RunService.PreSimulation:Connect(function()
		if not flyEnabled then return end

		pcall(function()
			if not root or not root.Parent
				or not flyVelocity or not flyVelocity.Parent
				or not flyOrientation or not flyOrientation.Parent then
				return
			end

			local currentCamera = workspace.CurrentCamera
			if not currentCamera then return end

			local cameraCFrame = currentCamera.CFrame
			local cameraForward = cameraCFrame.LookVector.Unit
			local cameraRight = Vector3.new(
				cameraCFrame.RightVector.X,
				0,
				cameraCFrame.RightVector.Z
			)

			if cameraRight.Magnitude > 0.001 then
				cameraRight = cameraRight.Unit
			else
				cameraRight = Vector3.new(1, 0, 0)
			end

			local bodyForward = getBodyForward(root, cameraCFrame)
			flyOrientation.CFrame = CFrame.lookAt(Vector3.zero, bodyForward, Vector3.yAxis)

			local movement = Vector3.zero
			if not UIS:GetFocusedTextBox() then
				if UIS:IsKeyDown(Enum.KeyCode.W) then movement += cameraForward end
				if UIS:IsKeyDown(Enum.KeyCode.S) then movement -= cameraForward end
				if UIS:IsKeyDown(Enum.KeyCode.A) then movement -= cameraRight end
				if UIS:IsKeyDown(Enum.KeyCode.D) then movement += cameraRight end
				if UIS:IsKeyDown(Enum.KeyCode.Space) then movement += Vector3.yAxis end
				if UIS:IsKeyDown(Enum.KeyCode.LeftControl)
					or UIS:IsKeyDown(Enum.KeyCode.RightControl) then
					movement -= Vector3.yAxis
				end
			end

			if movement.Magnitude > 1 then
				movement = movement.Unit
			end

			flyVelocity.VectorVelocity = movement * flySpeed
		end)
	end)

	return true
end

local function setFly(state)
	if state then
		flyEnabled = true
		if not setupFly() then
			flyEnabled = false
			setStatus("FLY INITIALIZATION FAILED", C.RED)
			return false
		end
		setStatus("CAMERA FLY ENABLED", C.GREEN)
		return true
	end

	flyEnabled = false
	cleanupFly()
	setStatus("FLY DISABLED", C.RED)
	return true
end

local flyButton
flyButton, setFlyState = makeToggle(movementCard, "CAMERA FLY", 191, setFly)

--========================================================
-- LOCAL NOCLIP ENGINE (CLIENT STEPPED)
--========================================================

local noclipConnection = nil
local noclipOriginalCollide = {}

local function stopNoclip()
	if noclipConnection then
		pcall(function()
			noclipConnection:Disconnect()
		end)
		noclipConnection = nil
	end

	local character = LP.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				pcall(function()
					if noclipOriginalCollide[part] ~= nil then
						part.CanCollide = noclipOriginalCollide[part]
					elseif part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" then
						part.CanCollide = true
					end
				end)
			end
		end
	end
	noclipOriginalCollide = {}
end

local function startNoclip()
	stopNoclip()
	noclipConnection = RunService.Stepped:Connect(function()
		if not noclipEnabled or isFlinging then return end
		pcall(function()
			local character = LP.Character
			if not character then return end
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					if noclipOriginalCollide[part] == nil then
						noclipOriginalCollide[part] = true
					end
					part.CanCollide = false
				end
			end
		end)
	end)
end

local noclipButton
noclipButton, setNoclipState = makeToggle(movementCard, "NOCLIP / 穿墙", 241, function(state)
	noclipEnabled = state
	if state then
		startNoclip()
		setStatus("LOCAL NOCLIP ENABLED", C.GREEN)
	else
		stopNoclip()
		setStatus("LOCAL NOCLIP DISABLED", C.RED)
	end
	return true
end)

--========================================================
-- LOCAL INVISIBILITY ENGINE
--========================================================

local invisibleConnection = nil
local invisibleSavedProps = {}

local function getHiddenProperty(object)
	if object:IsA("BasePart")
		or object:IsA("Decal")
		or object:IsA("Texture") then
		return "Transparency", object.Transparency
	end

	if object:IsA("ParticleEmitter")
		or object:IsA("Trail")
		or object:IsA("Beam")
		or object:IsA("Fire")
		or object:IsA("Smoke")
		or object:IsA("Sparkles")
		or object:IsA("BillboardGui")
		or object:IsA("SurfaceGui")
		or object:IsA("Highlight") then
		return "Enabled", object.Enabled
	end

	return nil
end

local function applyHideToCharacter(character)
	if not character then return end
	for _, object in ipairs(character:GetDescendants()) do
		local prop, orig = getHiddenProperty(object)
		if prop then
			if invisibleSavedProps[object] == nil then
				invisibleSavedProps[object] = {
					property = prop,
					original = orig,
				}
			end
			pcall(function()
				object[prop] = (prop == "Transparency") and 1 or false
			end)
		end
	end
end

local function stopInvisible()
	if invisibleConnection then
		pcall(function()
			invisibleConnection:Disconnect()
		end)
		invisibleConnection = nil
	end

	for object, data in pairs(invisibleSavedProps) do
		if object and object.Parent then
			pcall(function()
				object[data.property] = data.original
			end)
		end
	end
	invisibleSavedProps = {}
end

local function startInvisible()
	stopInvisible()
	pcall(function()
		applyHideToCharacter(LP.Character)
	end)

	invisibleConnection = RunService.RenderStepped:Connect(function()
		if not invisibleEnabled then return end
		pcall(function()
			applyHideToCharacter(LP.Character)
		end)
	end)
end

local invisibleButton
invisibleButton, setInvisibleState = makeToggle(movementCard, "INVISIBILITY / 隐身", 291, function(state)
	invisibleEnabled = state
	if state then
		startInvisible()
		setStatus("LOCAL INVISIBILITY ENABLED", C.GREEN)
	else
		stopInvisible()
		setStatus("LOCAL INVISIBILITY DISABLED", C.RED)
	end
	return true
end)

--========================================================
-- INFINITE JUMP + RESPAWN + SPEED ENFORCEMENT
--========================================================

trackConnection(UIS.JumpRequest:Connect(function()
	if not infiniteJump then return end

	pcall(function()
		local character = LP.Character
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
end))

trackConnection(RunService.Heartbeat:Connect(function()
	if customWalkSpeed ~= nil then
		pcall(function()
			local _, humanoid = getParts(LP)
			if humanoid and humanoid.WalkSpeed ~= customWalkSpeed then
				humanoid.WalkSpeed = customWalkSpeed
			end
		end)
	end
end))

trackConnection(LP.CharacterRemoving:Connect(function()
	cleanupFly()
	noclipOriginalCollide = {}
	invisibleSavedProps = {}
end))

trackConnection(LP.CharacterAdded:Connect(function()
	task.wait(0.5)
	if flyEnabled and not setupFly() then
		flyEnabled = false
		setFlyState(false, true)
	end
	if noclipEnabled then
		startNoclip()
	end
	if invisibleEnabled then
		startInvisible()
	end
	if customWalkSpeed ~= nil then
		pcall(function()
			local _, humanoid = getParts(LP)
			if humanoid then
				humanoid.WalkSpeed = customWalkSpeed
			end
		end)
	end
end))

--========================================================
-- ESP SYSTEM
--========================================================

local espCard = createSection(espPage, "ESP // VISUAL SYSTEM", 145)
local espObjects = {}
local playerConnections = {}

local function cleanupESP(data)
	if not data then return end

	for _, connection in ipairs(data.connections or {}) do
		pcall(function() connection:Disconnect() end)
	end

	for _, object in ipairs(data.objects or {}) do
		pcall(function() object:Destroy() end)
	end
end

local function removeESP(player)
	local data = espObjects[player]
	if not data then return end
	cleanupESP(data)
	espObjects[player] = nil
end

local function createESP(player)
	if not espEnabled or player == LP then return end
	removeESP(player)

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return end

	local objects = {}
	local connections = {}

	local ok, err = pcall(function()
		local highlight = create("Highlight", {
			Name = "EV03_Highlight",
			Adornee = character,
			FillColor = C.RED,
			OutlineColor = C.WHITE,
			FillTransparency = 0.82,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		}, espGui)
		if highlight then table.insert(objects, highlight) end

		local box = create("BoxHandleAdornment", {
			Name = "EV03_Box",
			Adornee = root,
			Size = Vector3.new(4, 6, 2),
			CFrame = CFrame.new(0, 1.5, 0),
			Color3 = C.RED,
			Transparency = 0.25,
			AlwaysOnTop = true,
			ZIndex = 10,
		}, espGui)
		if box then table.insert(objects, box) end

		local billboard = create("BillboardGui", {
			Name = "EV03_Info",
			Adornee = root,
			Size = UDim2.fromOffset(140, 40),
			StudsOffset = Vector3.new(0, 4, 0),
			AlwaysOnTop = true,
		}, espGui)
		if billboard then table.insert(objects, billboard) end

		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = player.Name,
			TextColor3 = C.WHITE,
			TextStrokeTransparency = 0.2,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
		}, billboard)

		local bar = create("Frame", {
			Size = UDim2.new(1, -12, 0, 8),
			Position = UDim2.fromOffset(6, 25),
			BackgroundColor3 = C.PANEL2,
			BorderSizePixel = 0,
		}, billboard)
		create("UICorner", {CornerRadius = UDim.new(1, 0)}, bar)

		local fill = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.GREEN,
			BorderSizePixel = 0,
		}, bar)
		create("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)

		local function updateHealth()
			pcall(function()
				if not fill or not fill.Parent or not humanoid or not humanoid.Parent then return end

				local ratio = math.clamp(
					humanoid.Health / math.max(humanoid.MaxHealth, 1),
					0,
					1
				)

				fill.Size = UDim2.fromScale(ratio, 1)
				fill.BackgroundColor3 = ratio > 0.5 and C.GREEN or C.RED
			end)
		end

		updateHealth()
		table.insert(connections, humanoid.HealthChanged:Connect(updateHealth))
		table.insert(connections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth))
	end)

	if not ok then
		warn("[EV03 ESP ERROR]", err)
		cleanupESP({objects = objects, connections = connections})
		return
	end

	espObjects[player] = {objects = objects, connections = connections}
end

local espButton
espButton, setESPState = makeToggle(espCard, "PLAYER ESP", 42, function(state)
	espEnabled = state

	if not state then
		for player in pairs(espObjects) do
			removeESP(player)
		end
		setStatus("ESP DISABLED", C.RED)
		return true
	end

	for _, player in ipairs(Players:GetPlayers()) do
		createESP(player)
	end

	setStatus("ESP ENABLED", C.GREEN)
	return true
end)

create("TextLabel", {
	Size = UDim2.new(1, -24, 0, 25),
	Position = UDim2.fromOffset(12, 91),
	BackgroundTransparency = 1,
	Text = "HIGHLIGHT / BOX / NAME / HEALTH",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
}, espCard)

local function hookPlayer(player)
	if player == LP or playerConnections[player] then return end

	local connections = {}
	table.insert(connections, player.CharacterAdded:Connect(function()
		task.wait(0.3)
		if espEnabled and player.Parent == Players then
			createESP(player)
		end
	end))

	table.insert(connections, player.CharacterRemoving:Connect(function()
		removeESP(player)
	end))

	playerConnections[player] = connections
	if espEnabled and player.Character then
		createESP(player)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end

trackConnection(Players.PlayerAdded:Connect(hookPlayer))
trackConnection(Players.PlayerRemoving:Connect(function(player)
	removeESP(player)

	local connections = playerConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			pcall(function() connection:Disconnect() end)
		end
		playerConnections[player] = nil
	end
end))

--========================================================
-- FEATURE HANDLERS & PANIC RESET
--========================================================

local handlers = {}

handlers.TeleportTarget = teleportToTarget
handlers.FlingTarget = flingTarget
handlers.FlingAll = flingAll

handlers.InfiniteJump = function()
	setJumpState(not infiniteJump)
end

handlers.ApplyWalkSpeed = applyWalkSpeed
handlers.Fly = function()
	setFlyState(not flyEnabled)
end
handlers.ApplyFlySpeed = applyFlySpeed
handlers.Noclip = function()
	setNoclipState(not noclipEnabled)
end
handlers.ESP = function()
	setESPState(not espEnabled)
end
handlers.Invisible = function()
	setInvisibleState(not invisibleEnabled)
end

handlers.Panic = function()
	isFlinging = false
	setJumpState(false)
	setFlyState(false)
	setESPState(false)
	setNoclipState(false)
	setInvisibleState(false)

	customWalkSpeed = nil
	if walkInput then
		walkInput.Text = "16"
	end

	pcall(function()
		local _, humanoid = getParts(LP)
		if humanoid then
			humanoid.WalkSpeed = 16
		end
	end)

	setStatus("PANIC RESET COMPLETE", C.RED)
end

--========================================================
-- HOTKEY GROUP
--========================================================

local hotkeyCard = createSection(hotkeyPage, "HOTKEYS // 快捷键分组", 605)

create("TextLabel", {
	Size = UDim2.new(1, -24, 0, 35),
	Position = UDim2.fromOffset(12, 37),
	BackgroundTransparency = 1,
	Text = "点击右侧按钮，再按下想绑定的新按键。\n重复按键会自动解除之前的绑定。",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, hotkeyCard)

local bindings = {
	TeleportTarget = Enum.KeyCode.T,
	FlingTarget = Enum.KeyCode.G,
	FlingAll = Enum.KeyCode.H,
	InfiniteJump = Enum.KeyCode.J,
	ApplyWalkSpeed = Enum.KeyCode.U,
	Fly = Enum.KeyCode.F,
	ApplyFlySpeed = Enum.KeyCode.Y,
	Noclip = Enum.KeyCode.N,
	ESP = Enum.KeyCode.E,
	Invisible = Enum.KeyCode.V,
	Panic = Enum.KeyCode.P,
	ToggleMenu = Enum.KeyCode.RightShift,
}

handlers.ToggleMenu = function()
	pcall(function()
		if gui then
			gui.Enabled = not gui.Enabled
		end
	end)
end

local bindingRows = {
	{"TeleportTarget", "指定玩家传送"},
	{"FlingTarget", "指定玩家甩飞"},
	{"FlingAll", "全体玩家甩飞"},
	{"InfiniteJump", "无限跳跃"},
	{"ApplyWalkSpeed", "应用移动速度"},
	{"Fly", "摄像机飞行开关"},
	{"ApplyFlySpeed", "应用飞行速度"},
	{"Noclip", "穿墙开关"},
	{"ESP", "ESP 开关"},
	{"Invisible", "隐身开关"},
	{"Panic", "Panic"},
	{"ToggleMenu", "菜单显示 / 隐藏"},
}

local bindButtons = {}
local listeningAction = nil

local function refreshBindingLabels()
	for action, button in pairs(bindButtons) do
		pcall(function()
			if button and button.Parent then
				button.Text = bindings[action] and bindings[action].Name or "UNBOUND"
				button.BackgroundColor3 = C.DARK_RED
			end
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
		if bindButton then
			bindButton.Text = "PRESS KEY..."
			bindButton.BackgroundColor3 = C.GREEN
		end
		setStatus("REBINDING: " .. label, C.YELLOW)
	end)

	bindButtons[action] = bindButton
end

makeButton(hotkeyCard, "PANIC // DISABLE ALL", 0, 555, 1, 30, handlers.Panic)

--========================================================
-- ABOUT / IDENTITY
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
		"项目版本：V3.8 (Standalone Edition)",
		"项目类型：纯客户端独立注入脚本",
		"飞行模式：CAMERA DIRECTION",
		"",
		"CREATOR IDENTITY",
		"",
		"创作者：阿叶ev03",
		"身份：Creator / Developer",
		"项目归属：EV03",
	}, "\n"),
	TextColor3 = C.WHITE,
	TextSize = 12,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
}, aboutCard)

--========================================================
-- DEFAULT PAGE
--========================================================

local function selectPage(name)
	if not pages[name] then return end

	for pageName, page in pairs(pages) do
		if page then
			page.Visible = (pageName == name)
		end
	end

	for pageName, button in pairs(navButtons) do
		if button then
			local selected = (pageName == name)
			button.BackgroundColor3 = selected and C.DARK_RED or C.SIDEBAR
			button.TextColor3 = selected and C.WHITE or C.GRAY
		end
	end
end

selectPage("DASHBOARD")

--========================================================
-- WINDOW DRAG
--========================================================

local dragging = false
local dragStart
local startPosition
local dragInput

if dragArea then
	trackConnection(dragArea.InputBegan:Connect(function(input)
		pcall(function()
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then

				dragging = true
				dragStart = input.Position
				startPosition = main.Position

				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
	end))

	trackConnection(dragArea.InputChanged:Connect(function(input)
		pcall(function()
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)
	end))
end

trackConnection(UIS.InputChanged:Connect(function(input)
	if not dragging or input ~= dragInput then return end
	pcall(function()
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end)
end))

--========================================================
-- MINIMIZE / HIDE
--========================================================

local minimized = false
local originalSize = main and main.Size or UDim2.fromOffset(windowWidth, windowHeight)

if minimizeButton then
	trackConnection(minimizeButton.MouseButton1Click:Connect(function()
		pcall(function()
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
	end))
end

if closeButton then
	trackConnection(closeButton.MouseButton1Click:Connect(function()
		pcall(function()
			gui.Enabled = false
		end)
	end))
end

--========================================================
-- ALL CUSTOM HOTKEYS
--========================================================

trackConnection(UIS.InputBegan:Connect(function(input, processed)
	pcall(function()
		if listeningAction then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end

			if input.KeyCode == Enum.KeyCode.Escape then
				listeningAction = nil
				refreshBindingLabels()
				setStatus("BINDING CANCELLED", C.YELLOW)
				return
			end

			if input.KeyCode == Enum.KeyCode.Unknown then
				return
			end

			local action = listeningAction
			listeningAction = nil

			for otherAction, otherKey in pairs(bindings) do
				if otherAction ~= action and otherKey == input.KeyCode then
					bindings[otherAction] = nil
				end
			end

			bindings[action] = input.KeyCode
			refreshBindingLabels()
			setStatus(action .. " KEY: " .. input.KeyCode.Name, C.GREEN)
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if processed then return end
		if UIS:GetFocusedTextBox() then return end

		for action, key in pairs(bindings) do
			if key and key == input.KeyCode then
				local handler = handlers[action]
				if handler then
					local success, err = pcall(handler)
					if not success then
						warn("[EV03 HOTKEY ERROR]", err)
						setStatus("HOTKEY ERROR", C.RED)
					end
				end
				return
			end
		end
	end)
end))

--========================================================
-- GLOBAL CLEANUP HOOK (FOR RE-INJECTION)
--========================================================

local function fullCleanup()
	isFlinging = false
	flyEnabled = false
	noclipEnabled = false
	invisibleEnabled = false
	espEnabled = false
	customWalkSpeed = nil

	cleanupFly()
	stopNoclip()
	stopInvisible()

	for player in pairs(espObjects) do
		removeESP(player)
	end

	for _, connections in pairs(playerConnections) do
		for _, connection in ipairs(connections) do
			pcall(function() connection:Disconnect() end)
		end
	end
	playerConnections = {}

	for _, connection in ipairs(activeConnections) do
		pcall(function() connection:Disconnect() end)
	end
	activeConnections = {}

	if espGui then
		pcall(function() espGui:Destroy() end)
	end

	if gui then
		pcall(function() gui:Destroy() end)
	end
end

pcall(function()
	if getgenv and type(getgenv) == "function" then
		getgenv().EV03_CLEANUP = fullCleanup
	end
end)

--========================================================
-- READY
--========================================================

refreshBindingLabels()
setStatus("EV03 STANDALONE V3.8 READY", C.GREEN)

print("======================================")
print(" EV03 CONTROL V3.8 - STANDALONE")
print(" CREATOR: 阿叶ev03")
print(" PURE CLIENT MODE: READY")
print(" CAMERA DIRECTION FLY: READY")
print(" LOCAL NOCLIP / INVISIBLE: READY")
print(" CLIENT COLLISION FLING: READY")
print(" HOTKEY TOGGLE MENU: RightShift")
print("======================================")
