--========================================================
-- EV03 CONTROL V3.8 - EXECUTOR STANDALONE EDITION
-- Creator: 阿叶ev03
-- Running completely on Client (No Server Scripts Required)
--========================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui", 10)
if not PG then return end

--========================================================
-- CLEAN OLD GUI
--========================================================

for _, name in ipairs({"EV03_CONTROL", "EV03_ESP"}) do
	local old = PG:FindFirstChild(name)
	if old then pcall(function() old:Destroy() end) end
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

local function validNumber(n)
	return typeof(n) == "number"
		and n == n
		and n ~= math.huge
		and n ~= -math.huge
end

local function create(className, props, parent)
	local obj = Instance.new(className)
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

--========================================================
-- WINDOW SIZE & UTILS
--========================================================

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)

local windowWidth = math.floor(math.clamp(viewport.X - 30, 560, 900))
local windowHeight = math.floor(math.clamp(viewport.Y - 40, 440, 680))

local function getParts(player)
	player = player or LP
	local character = player.Character
	if not character then return nil, nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return character, humanoid, root
	end
	return character, humanoid, root
end

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

	if exactMatch then return exactMatch end
	if #matches == 1 then return matches[1] end
	if #matches == 0 then return nil, "PLAYER NOT FOUND" end

	local names = {}
	for index = 1, math.min(#matches, 5) do
		table.insert(names, matches[index].Name)
	end
	local suffix = #matches > 5 and " ..." or ""
	return nil, "MULTIPLE MATCHES: " .. table.concat(names, ", ") .. suffix
end

--========================================================
-- GUI CREATION
--========================================================

local gui = create("ScreenGui", {
	Name = "EV03_CONTROL",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PG)

local espGui = create("ScreenGui", {
	Name = "EV03_ESP",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PG)

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
	Text = "STANDALONE EDITION // V3.8",
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
		pcall(function()
			local ok, err = pcall(callback)
			if not ok then
				warn("[EV03 UI ERROR]", err)
				setStatus("LOCAL ACTION ERROR", C.RED)
			end
		end)
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
				desired = false
			elseif result == false then
				desired = false
			end
		end
		active = desired
		pcall(function()
			button.Text = title .. (active and "  //  ON" or "  //  OFF")
			button.BackgroundColor3 = active and C.GREEN or C.DARK_RED
		end)
		return active
	end

	button = makeButton(parent, title .. "  //  OFF", 0, y, 1, 38, function()
		setState(not active)
	end)

	return button, setState
end

--========================================================
-- NAVIGATION PAGES
--========================================================

local dashboardPage = createPage("DASHBOARD")
local playerPage = createPage("PLAYER")
local movementPage = createPage("MOVEMENT")
local espPage = createPage("ESP")
local hotkeyPage = createPage("HOTKEYS")
local aboutPage = createPage("ABOUT")

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
			page.Visible = (pageName == name)
		end
		for pageName, nav in pairs(navButtons) do
			local selected = (pageName == name)
			nav.BackgroundColor3 = selected and C.DARK_RED or C.SIDEBAR
			nav.TextColor3 = selected and C.WHITE or C.GRAY
		end
		setStatus("PAGE: " + name)
	end)
end

addNavigation("DASHBOARD", "Dashboard", "◆")
addNavigation("PLAYER", "Player", "◈")
addNavigation("MOVEMENT", "Movement", "↗")
addNavigation("ESP", "ESP System", "◎")
addNavigation("HOTKEYS", "Hotkeys", "⌨")
addNavigation("ABOUT", "About", "ⓘ")

--========================================================
-- FEATURE 1: CLIENT NOCLIP (穿墙本地实现)
--========================================================

local noclipEnabled = false
local noclipConnection = nil

local function setNoclip(state)
	noclipEnabled = state
	if noclipConnection then
		pcall(function() noclipConnection:Disconnect() end)
		noclipConnection = nil
	end

	if state then
		noclipConnection = RunService.Stepped:Connect(function()
			pcall(function()
				if not noclipEnabled then return end
				local char = LP.Character
				if not char then return end
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end)
		end)
		setStatus("NOCLIP ENABLED", C.GREEN)
	else
		pcall(function()
			local char = LP.Character
			if char then
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = true
					end
				end
			end
		end)
		setStatus("NOCLIP DISABLED", C.RED)
	end
	return true
end

--========================================================
-- FEATURE 2: CLIENT INVISIBILITY (隐身本地实现)
--========================================================

local invisibleEnabled = false

local function setInvisible(state)
	invisibleEnabled = state
	pcall(function()
		local char = LP.Character
		if not char then return end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = state and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
		end
		for _, desc in ipairs(char:GetDescendants()) do
			if desc:IsA("BasePart") or desc:IsA("Decal") then
				desc.Transparency = state and 1 or (desc.Name == "HumanoidRootPart" and 1 or 0)
			elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
				desc.Enabled = not state
			end
		end
	end)
	setStatus(state and "INVISIBILITY ENABLED" or "INVISIBILITY DISABLED", state and C.GREEN or C.RED)
	return true
end

--========================================================
-- FEATURE 3: CLIENT FLING / TELEPORT (甩飞 & 传送本地实现)
--========================================================

local function clientTeleportTarget(targetName)
	local target = findTarget(targetName)
	if not target then
		setStatus("PLAYER NOT FOUND", C.RED)
		return
	end
	if target == LP then
		setStatus("CANNOT TARGET YOURSELF", C.RED)
		return
	end

	pcall(function()
		local _, _, myRoot = getParts(LP)
		local targetChar, _, targetRoot = getParts(target)
		if myRoot and targetRoot and targetChar then
			myRoot.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 3)
			setStatus("TELEPORTED TO: " .. target.Name, C.GREEN)
		else
			setStatus("CHARACTER NOT READY", C.RED)
		end
	end)
end

local function clientFlingTarget(targetName, power)
	local target = findTarget(targetName)
	if not target then
		setStatus("PLAYER NOT FOUND", C.RED)
		return
	end
	if target == LP then
		setStatus("CANNOT TARGET YOURSELF", C.RED)
		return
	end

	task.spawn(function()
		pcall(function()
			local char, humanoid, root = getParts(LP)
			local targetChar, _, targetRoot = getParts(target)
			if not char or not root or not targetRoot then
				setStatus("CHARACTER NOT READY", C.RED)
				return
			end

			setStatus("FLINGING: " .. target.Name, C.YELLOW)
			
			local vel = Instance.new("BodyVelocity")
			vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			vel.Velocity = Vector3.new(0, 9999, 0)
			vel.Parent = root

			local bav = Instance.new("BodyAngularVelocity")
			bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			bav.AngularVelocity = Vector3.new(9999, 9999, 9999)
			bav.Parent = root

			local savedCFrame = root.CFrame
			local startTime = tick()

			while tick() - startTime < 0.6 do
				RunService.Heartbeat:Wait()
				if targetRoot and targetRoot.Parent then
					root.CFrame = targetRoot.CFrame
				end
			end

			vel:Destroy()
			bav:Destroy()
			root.CFrame = savedCFrame
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			setStatus("FLING COMPLETE", C.GREEN)
		end)
	end)
end

local function clientFlingAll(power)
	task.spawn(function()
		pcall(function()
			local char, _, root = getParts(LP)
			if not char or not root then return end
			setStatus("FLINGING ALL PLAYERS...", C.YELLOW)

			local vel = Instance.new("BodyVelocity")
			vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			vel.Velocity = Vector3.new(0, 9999, 0)
			vel.Parent = root

			local bav = Instance.new("BodyAngularVelocity")
			bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			bav.AngularVelocity = Vector3.new(9999, 9999, 9999)
			bav.Parent = root

			local savedCFrame = root.CFrame
			local startTime = tick()

			while tick() - startTime < 0.9 do
				RunService.Heartbeat:Wait()
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= LP then
						local _, _, tRoot = getParts(p)
						if tRoot then
							root.CFrame = tRoot.CFrame
						end
					end
				end
			end

			vel:Destroy()
			bav:Destroy()
			root.CFrame = savedCFrame
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			setStatus("FLING ALL COMPLETE", C.GREEN)
		end)
	end)
end

--========================================================
-- DASHBOARD PAGE
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
	Text = "Creator: 阿叶ev03\nVersion: V3.8 (Standalone Edition)\nPure Client-Side Execution",
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
	Text = "纯客户端本地暴力物理机制",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
}, playerCard)

makeButton(playerCard, "TELEPORT TO ME", 0, 145, 0.32, 40, function()
	local name = targetInput.Text:match("^%s*(.-)%s*$")
	if name and name ~= "" then clientTeleportTarget(name) end
end)

makeButton(playerCard, "FLING TARGET", 0.34, 145, 0.32, 40, function()
	local name = targetInput.Text:match("^%s*(.-)%s*$")
	local power = tonumber(flingPowerInput.Text) or 10
	if name and name ~= "" then clientFlingTarget(name, power) end
end)

makeButton(playerCard, "FLING ALL", 0.68, 145, 0.32, 40, function()
	local power = tonumber(flingPowerInput.Text) or 10
	clientFlingAll(power)
end)

--========================================================
-- MOVEMENT PAGE (Fly, Speed, Noclip, Invisible)
--========================================================

local movementCard = createSection(movementPage, "MOVEMENT // FLY / SPEED / NOCLIP", 365)

local infiniteJump = false
local setJumpState
makeToggle(movementCard, "INFINITE JUMP", 42, function(state)
	infiniteJump = state
	return true
end)

local walkInput = makeInput(movementCard, "Walk speed (finite number)", 0, 91, 0.62, 36, "32")
makeButton(movementCard, "APPLY WALK SPEED", 0.65, 91, 0.35, 36, function()
	local speed = tonumber(walkInput.Text)
	if validNumber(speed) then
		pcall(function()
			local _, humanoid = getParts(LP)
			if humanoid then humanoid.WalkSpeed = speed end
		end)
		setStatus("WALK SPEED: " .. tostring(speed), C.GREEN)
	end
end)

local flySpeed = 80
local flyInput = makeInput(movementCard, "Fly speed (finite number)", 0, 141, 0.62, 36, "80")
makeButton(movementCard, "APPLY FLY SPEED", 0.65, 141, 0.35, 36, function()
	local speed = tonumber(flyInput.Text)
	if validNumber(speed) then
		flySpeed = speed
		setStatus("FLY SPEED: " .. tostring(speed), C.GREEN)
	end
end)

--========================================================
-- CAMERA DIRECTION FLY ENGINE (本地摄像机飞行)
--========================================================

local flyEnabled = false
local flyConnection = nil

local function setFly(state)
	flyEnabled = state
	if flyConnection then
		pcall(function() flyConnection:Disconnect() end)
		flyConnection = nil
	end

	if state then
		flyConnection = RunService.RenderStepped:Connect(function()
			pcall(function()
				if not flyEnabled then return end
				local char, humanoid, root = getParts(LP)
				if not char or not root or not humanoid then return end

				local cam = Workspace.CurrentCamera
				if not cam then return end

				humanoid.PlatformStand = true
				local moveVector = Vector3.new()

				if not UIS:GetFocusedTextBox() then
					if UIS:IsKeyDown(Enum.KeyCode.W) then moveVector += cam.CFrame.LookVector end
					if UIS:IsKeyDown(Enum.KeyCode.S) then moveVector -= cam.CFrame.LookVector end
					if UIS:IsKeyDown(Enum.KeyCode.A) then moveVector -= cam.CFrame.RightVector end
					if UIS:IsKeyDown(Enum.KeyCode.D) then moveVector += cam.CFrame.RightVector end
					if UIS:IsKeyDown(Enum.KeyCode.Space) then moveVector += Vector3.new(0, 1, 0) end
					if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then moveVector -= Vector3.new(0, 1, 0) end
				end

				if moveVector.Magnitude > 0 then
					moveVector = moveVector.Unit * flySpeed
				end

				root.AssemblyLinearVelocity = moveVector
				root.CFrame = CFrame.new(root.Position, root.Position + cam.CFrame.LookVector)
			end)
		end)
		setStatus("CAMERA FLY ENABLED", C.GREEN)
	else
		pcall(function()
			local _, humanoid, root = getParts(LP)
			if humanoid then
				humanoid.PlatformStand = false
			end
			if root then
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end)
		setStatus("FLY DISABLED", C.RED)
	end
	return true
end

makeToggle(movementCard, "CAMERA FLY", 191, setFly)

local _, setNoclipState = makeToggle(movementCard, "NOCLIP / 穿墙", 241, function(state)
	return setNoclip(state)
end)

local _, setInvisibleState = makeToggle(movementCard, "INVISIBILITY / 隐身", 291, function(state)
	return setInvisible(state)
end)

-- Infinite Jump Hook
UIS.JumpRequest:Connect(function()
	if not infiniteJump then return end
	pcall(function()
		local _, humanoid = getParts(LP)
		if humanoid and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
end)

--========================================================
-- ESP SYSTEM (本地透视高亮)
--========================================================

local espCard = createSection(espPage, "ESP // VISUAL SYSTEM", 145)
local espEnabled = false
local espObjects = {}

local function removeESP(player)
	if espObjects[player] then
		pcall(function()
			for _, obj in ipairs(espObjects[player]) do
				obj:Destroy()
			end
		end)
		espObjects[player] = nil
	end
end

local function createESP(player)
	if player == LP then return end
	removeESP(player)
	pcall(function()
		local char = player.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end

		local objects = {}
		local hl = create("Highlight", {
			Adornee = char,
			FillColor = C.RED,
			OutlineColor = C.WHITE,
			FillTransparency = 0.8,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		}, char)
		table.insert(objects, hl)

		local bb = create("BillboardGui", {
			Adornee = root,
			Size = UDim2.fromOffset(120, 30),
			StudsOffset = Vector3.new(0, 3.5, 0),
			AlwaysOnTop = true,
		}, espGui)
		table.insert(objects, bb)

		create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = player.Name,
			TextColor3 = C.WHITE,
			TextStrokeTransparency = 0.3,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
		}, bb)

		espObjects[player] = objects
	end)
end

makeToggle(espCard, "PLAYER ESP", 42, function(state)
	espEnabled = state
	if not state then
		for p in pairs(espObjects) do removeESP(p) end
	else
		for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
	end
	return true
end)

Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function()
		if espEnabled then task.wait(1) createESP(p) end
	end)
end)
Players.PlayerRemoving:Connect(removeESP)

create("TextLabel", {
	Size = UDim2.new(1, -24, 0, 25),
	Position = UDim2.fromOffset(12, 91),
	BackgroundTransparency = 1,
	Text = "CLIENT-SIDE HIGHLIGHT / NAME ESP",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
}, espCard)

--========================================================
-- HANDLERS & PANIC SYSTEM
--========================================================

local handlers = {}
handlers.Panic = function()
	setFly(false)
	setNoclip(false)
	setInvisible(false)
	espEnabled = false
	for p in pairs(espObjects) do removeESP(p) end
	pcall(function()
		local _, humanoid = getParts(LP)
		if humanoid then humanoid.WalkSpeed = 16 end
	end)
	setStatus("PANIC RESET COMPLETE", C.RED)
end

--========================================================
-- HOTKEYS
--========================================================

local hotkeyCard = createSection(hotkeyPage, "HOTKEYS // 快捷键分组", 605)

create("TextLabel", {
	Size = UDim2.new(1, -24, 0, 35),
	Position = UDim2.fromOffset(12, 37),
	BackgroundTransparency = 1,
	Text = "点击右侧按钮，再按下想绑定的新按键。\n支持纯本地按键响应。",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, hotkeyCard)

local bindings = {
	Fly = Enum.KeyCode.F,
	Noclip = Enum.KeyCode.N,
	ESP = Enum.KeyCode.E,
	Invisible = Enum.KeyCode.V,
	Panic = Enum.KeyCode.P,
	ToggleMenu = Enum.KeyCode.RightShift,
}

handlers.ToggleMenu = function()
	gui.Enabled = not gui.Enabled
end
handlers.Fly = function() setFly(not flyEnabled) end
handlers.Noclip = function() setNoclip(not noclipEnabled) end
handlers.Invisible = function() setInvisible(not invisibleEnabled) end
handlers.ESP = function() 
	espEnabled = not espEnabled
	if espEnabled then
		for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
	else
		for p in pairs(espObjects) do removeESP(p) end
	end
end

local bindingRows = {
	{"Fly", "摄像机飞行开关"},
	{"Noclip", "穿墙开关"},
	{"ESP", "ESP 开关"},
	{"Invisible", "隐身开关"},
	{"Panic", "Panic / 一键紧急重置"},
	{"ToggleMenu", "菜单显示 / 隐藏"},
}

local bindButtons = {}
local listeningAction = nil

local function refreshBindingLabels()
	for action, button in pairs(bindButtons) do
		pcall(function()
			button.Text = bindings[action] and bindings[action].Name or "UNBOUND"
			button.BackgroundColor3 = C.DARK_RED
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
	bindButton = makeButton(hotkeyCard, bindings[action] and bindings[action].Name or "NONE", 0.63, y, 0.34, 32, function()
		listeningAction = action
		bindButton.Text = "PRESS KEY..."
		bindButton.BackgroundColor3 = C.GREEN
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
		"项目版本：V3.8 (Standalone)",
		"项目类型：Executor Client Script",
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
-- SELECT DEFAULT PAGE
--========================================================

local function selectPage(name)
	if not pages[name] then return end
	for pageName, page in pairs(pages) do
		page.Visible = (pageName == name)
	end
	for pageName, button in pairs(navButtons) do
		local selected = (pageName == name)
		button.BackgroundColor3 = selected and C.DARK_RED or C.SIDEBAR
		button.TextColor3 = selected and C.WHITE or C.GRAY
	end
end
selectPage("DASHBOARD")

--========================================================
-- WINDOW DRAGGING & MINIMIZE LOGIC
--========================================================

local dragging = false
local dragStart = Vector3.new()
local startPosition = UDim2.new()
local dragInput = nil

dragArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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

dragArea.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UIS.InputChanged:Connect(function(input)
	if not dragging or input ~= dragInput then return end
	local delta = input.Position - dragStart
	main.Position = UDim2.new(
		startPosition.X.Scale,
		startPosition.X.Offset + delta.X,
		startPosition.Y.Scale,
		startPosition.Y.Offset + delta.Y
	)
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

--========================================================
-- GLOBAL HOTKEY LISTENER
--========================================================

UIS.InputBegan:Connect(function(input, processed)
	if listeningAction then
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode == Enum.KeyCode.Escape then
			listeningAction = nil
			refreshBindingLabels()
			setStatus("BINDING CANCELLED", C.YELLOW)
			return
		end
		if input.KeyCode == Enum.KeyCode.Unknown then return end

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
				pcall(handler)
			end
			return
		end
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
print(" 100% CLIENT-SIDE EXECUTOR EDITION")
print("======================================")
