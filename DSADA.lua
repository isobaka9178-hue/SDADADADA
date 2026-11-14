--========================================================
-- EV03 CONTROL V3.8 - EXECUTOR STANDALONE EDITION (FULL 100%)
-- CAMERA DIRECTION FLIGHT + PREFIX TARGETING + 3D ORBIT FLING
-- Creator: 阿叶ev03
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
	player = player or LP
	if not player or not player.Character then
		return nil, nil, nil
	end
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
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
-- WINDOW SIZE & GUI
--========================================================

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
local windowWidth = math.floor(math.clamp(viewport.X - 30, 560, 900))
local windowHeight = math.floor(math.clamp(viewport.Y - 40, 440, 680))

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
	Text = "CAMERA FLY STANDALONE // V3.8",
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
-- MAIN BODY & FOOTER
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
	Text = "SYSTEM READY",
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
-- PAGE & UI COMPONENT HELPERS
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
-- NAVIGATION SETUP
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

	button.MouseButton1Click:Connect(function()
		for pageName, page in pairs(pages) do
			page.Visible = (pageName == name)
		end
		for pageName, nav in pairs(navButtons) do
			local selected = (pageName == name)
			nav.BackgroundColor3 = selected and C.DARK_RED or C.SIDEBAR
			nav.TextColor3 = selected and C.WHITE or C.GRAY
		end
		setStatus("PAGE: " .. tostring(name))
	end)

	return button
end

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

local setJumpState
local setFlyState
local setNoclipState
local setInvisibleState
local setESPState

--========================================================
-- LOCAL SERVER-PORTED LOGIC: NOCLIP (纯客户端还原)
--========================================================

local noclipSession = nil

local function restoreNoclip()
	if not noclipSession then return end
	for _, conn in ipairs(noclipSession.connections) do
		pcall(function() conn:Disconnect() end)
	end
	for part, origCollide in pairs(noclipSession.parts) do
		if part and part.Parent then
			pcall(function() part.CanCollide = origCollide end)
		end
	end
	noclipSession = nil
end

local function applyNoclip(enabled)
	if not enabled then
		noclipEnabled = false
		restoreNoclip()
		setStatus("NOCLIP DISABLED", C.RED)
		return true
	end

	local character = LP.Character
	if not character then
		setStatus("CHARACTER NOT READY", C.RED)
		return false
	end

	noclipEnabled = true
	restoreNoclip()

	local session = {
		character = character,
		parts = {},
		connections = {},
	}
	noclipSession = session

	local function enforce(object)
		if not object:IsA("BasePart") then return end
		if not object:IsDescendantOf(character) then return end
		if session.parts[object] == nil then
			session.parts[object] = object.CanCollide
		end
		pcall(function()
			object.CanCollide = false
		end)
	end

	for _, object in ipairs(character:GetDescendants()) do
		enforce(object)
	end

	table.insert(session.connections, character.DescendantAdded:Connect(function(object)
		if noclipSession == session then enforce(object) end
	end))

	table.insert(session.connections, RunService.Stepped:Connect(function()
		if noclipSession ~= session then return end
		if LP.Character ~= character then
			restoreNoclip()
			return
		end
		for _, object in ipairs(character:GetDescendants()) do
			enforce(object)
		end
	end))

	setStatus("NOCLIP ENABLED", C.GREEN)
	return true
end

--========================================================
-- LOCAL SERVER-PORTED LOGIC: INVISIBILITY (纯客户端还原)
--========================================================

local invisibleSession = nil

local function getHiddenProperty(object)
	if object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture") then
		return "Transparency", object.Transparency
	end
	if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
		or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Sparkles")
		or object:IsA("BillboardGui") or object:IsA("SurfaceGui") or object:IsA("Highlight") then
		return "Enabled", object.Enabled
	end
	return nil
end

local function restoreInvisible()
	if not invisibleSession then return end
	for _, conn in ipairs(invisibleSession.connections) do
		pcall(function() conn:Disconnect() end)
	end
	for object, orig in pairs(invisibleSession.properties) do
		if object and object.Parent then
			pcall(function() object[orig.property] = orig.original end)
		end
	end
	if invisibleSession.humanoid and invisibleSession.humanoid.Parent then
		pcall(function()
			invisibleSession.humanoid.DisplayDistanceType = invisibleSession.displayDistanceType
		end)
	end
	invisibleSession = nil
end

local function applyInvisible(enabled)
	if not enabled then
		invisibleEnabled = false
		restoreInvisible()
		setStatus("INVISIBILITY DISABLED", C.RED)
		return true
	end

	local character = LP.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		setStatus("CHARACTER NOT READY", C.RED)
		return false
	end

	invisibleEnabled = true
	restoreInvisible()

	local session = {
		character = character,
		humanoid = humanoid,
		displayDistanceType = humanoid.DisplayDistanceType,
		properties = {},
		connections = {},
	}
	invisibleSession = session

	local function hideObject(object)
		if not object:IsDescendantOf(character) then return end
		local prop, orig = getHiddenProperty(object)
		if not prop then return end
		if session.properties[object] == nil then
			session.properties[object] = { property = prop, original = orig }
		end
		pcall(function()
			object[prop] = (prop == "Transparency") and 1 or false
		end)
	end

	pcall(function()
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		for _, object in ipairs(character:GetDescendants()) do
			hideObject(object)
		end
		table.insert(session.connections, character.DescendantAdded:Connect(function(object)
			if invisibleSession == session then hideObject(object) end
		end))
		table.insert(session.connections, RunService.PreSimulation:Connect(function()
			if invisibleSession ~= session then return end
			if LP.Character ~= character then
				restoreInvisible()
				return
			end
			for object, orig in pairs(session.properties) do
				if object and object.Parent then
					pcall(function()
						object[orig.property] = (orig.property == "Transparency") and 1 or false
					end)
				end
			end
			if humanoid.Parent then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end))
	end)

	setStatus("INVISIBILITY ENABLED", C.GREEN)
	return true
end

--========================================================
-- LOCAL SERVER-PORTED LOGIC: 3D ORBIT FLING & TELEPORT
--========================================================

local FLING_ORBIT_RADIUS = 12
local FLING_CONTACT_DISTANCE = 4.5
local FLING_BASE_SPEED = 90
local FLING_SPEED_PER_POWER = 28
local FLING_BASE_SPIN = 48
local FLING_SPIN_PER_POWER = 14

local activeFlingSession = nil

local function destroyFlingMovers(session)
	if not session then return end
	for _, mover in ipairs(session.movers) do
		if mover and mover.Parent then
			pcall(function() mover:Destroy() end)
		end
	end
	table.clear(session.movers)
end

local function finishFling(session)
	if activeFlingSession == session then
		activeFlingSession = nil
	end
	destroyFlingMovers(session)
	local character = session.character
	if character and character.Parent and LP.Character == character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		pcall(function()
			character:PivotTo(session.savedPivot)
			if root then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
			if humanoid then
				humanoid.AutoRotate = session.oldAutoRotate
				if humanoid.Health > 0 then
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end
		end)
	end
end

local function startClientFling(targets, power)
	if activeFlingSession then
		setStatus("FLING ALREADY ACTIVE", C.YELLOW)
		return
	end

	local character, humanoid, root = getParts(LP)
	if not character or not humanoid or not root then
		setStatus("CHARACTER NOT READY", C.RED)
		return
	end

	local validTargets = {}
	for _, target in ipairs(targets) do
		if target and target ~= LP and target.Parent == Players then
			table.insert(validTargets, target)
		end
	end

	if #validTargets == 0 then
		setStatus("NO VALID TARGETS", C.RED)
		return
	end

	local session = {
		character = character,
		savedPivot = character:GetPivot(),
		oldAutoRotate = humanoid.AutoRotate,
		movers = {},
	}
	activeFlingSession = session
	setStatus("3D SPIN FLING STARTED // POWER " .. tostring(power), C.YELLOW)

	task.spawn(function()
		local ok, err = pcall(function()
			humanoid.AutoRotate = false
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)

			for _, target in ipairs(validTargets) do
				if activeFlingSession ~= session or LP.Character ~= character or not character.Parent or humanoid.Health <= 0 then
					break
				end

				local targetCharacter, targetHumanoid, targetRoot = getParts(target)
				if targetCharacter and targetHumanoid and targetRoot and not targetRoot.Anchored then
					local initialOffset = root.Position - targetRoot.Position
					local initialHorizontalDistance = Vector3.new(initialOffset.X, 0, initialOffset.Z).Magnitude
					local horizontal = Vector3.new(initialOffset.X, 0, initialOffset.Z)
					if horizontal.Magnitude < 0.01 then
						horizontal = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
					end
					horizontal = horizontal.Magnitude < 0.01 and Vector3.new(1, 0, 0) or horizontal.Unit

					local startingRadius = math.max(FLING_ORBIT_RADIUS, initialOffset.Magnitude)
					local startAngle = math.atan2(initialOffset.Y, math.max(initialHorizontalDistance, 0.01))
					local orbitDuration = math.clamp(2.2 - power * 0.14, 0.8, 2.2)
					local maxSpeed = FLING_BASE_SPEED + power * FLING_SPEED_PER_POWER
					local spinSpeed = FLING_BASE_SPIN + power * FLING_SPIN_PER_POWER

					local attachment = Instance.new("Attachment", root)
					local alignPosition = Instance.new("AlignPosition")
					alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
					alignPosition.Attachment0 = attachment
					alignPosition.ApplyAtCenterOfMass = true
					alignPosition.RigidityEnabled = false
					alignPosition.MaxForce = 1000000000
					alignPosition.MaxVelocity = maxSpeed
					alignPosition.Responsiveness = 100 + power * 12

					local angularVelocity = Instance.new("AngularVelocity")
					angularVelocity.Attachment0 = attachment
					angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
					angularVelocity.MaxTorque = 1000000000
					angularVelocity.AngularVelocity = Vector3.new(spinSpeed * 12, spinSpeed * 15, spinSpeed * 12)

					local initialOrbitOffset = horizontal * (math.cos(startAngle) * startingRadius) + Vector3.yAxis * (math.sin(startAngle) * startingRadius)
					alignPosition.Position = targetRoot.Position + initialOrbitOffset
					alignPosition.Parent = root
					angularVelocity.Parent = root

					table.insert(session.movers, attachment)
					table.insert(session.movers, alignPosition)
					table.insert(session.movers, angularVelocity)

					-- 阶段1：3D 轨道蓄力环绕
					local orbitStarted = os.clock()
					while os.clock() - orbitStarted < orbitDuration do
						RunService.Heartbeat:Wait()
						if activeFlingSession ~= session or LP.Character ~= character or target.Character ~= targetCharacter or not targetRoot.Parent then
							break
						end
						local progress = math.clamp((os.clock() - orbitStarted) / orbitDuration, 0, 1)
						local angle = startAngle + progress * math.pi * 3
						local radius = startingRadius + (FLING_ORBIT_RADIUS - startingRadius) * progress
						local orbitOffset = horizontal * (math.cos(angle) * radius) + Vector3.yAxis * (math.sin(angle) * radius)
						alignPosition.Position = targetRoot.Position + orbitOffset
					end

					-- 阶段2：切入碰撞区进行物理碰撞甩飞（纯客户端高旋撞击）
					if activeFlingSession == session and target.Character == targetCharacter and targetRoot.Parent then
						local impactStarted = os.clock()
						while os.clock() - impactStarted < 0.65 do
							RunService.Heartbeat:Wait()
							if activeFlingSession ~= session or LP.Character ~= character or target.Character ~= targetCharacter or not targetRoot.Parent then
								break
							end
							-- 纯客户端利用高速旋转直接重叠碰撞目标 RootPart 传递动量
							alignPosition.Position = targetRoot.Position
							root.AssemblyLinearVelocity = Vector3.new(0, 120 + power * 40, 0)
							root.AssemblyAngularVelocity = Vector3.new(9999, 9999, 9999)
						end
					end

					destroyFlingMovers(session)
				end
			end
		end)

		finishFling(session)
		if ok then
			setStatus("FLING COMPLETE", C.GREEN)
		else
			warn("[EV03 FLING ERROR]", err)
			setStatus("FLING ERROR", C.RED)
		end
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
	Text = "Creator: 阿叶ev03\nVersion: V3.8 (Standalone Edition)\nCamera Direction Flight + 3D Orbit Fling",
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
	Text = "数值越大，绕转和击飞力道越强",
	TextColor3 = C.GRAY,
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
}, playerCard)

local function getTargetPlayer()
	local name = targetInput.Text:match("^%s*(.-)%s*$")
	if not name or name == "" then
		setStatus("PLEASE ENTER USERNAME", C.RED)
		return nil
	end
	local target, err = findTarget(name)
	if not target then
		setStatus(err or "PLAYER NOT FOUND", C.RED)
		return nil
	end
	if target == LP then
		setStatus("CANNOT TARGET YOURSELF", C.RED)
		return nil
	end
	return target
end

local function getFlingPower()
	local power = tonumber(flingPowerInput.Text)
	if not validNumber(power) or power < 1 or power > 10 then
		setStatus("甩飞力道必须是 1 到 10", C.RED)
		return nil
	end
	return math.floor(power + 0.5)
end

local function teleportTarget()
	local target = getTargetPlayer()
	if not target then return end

	local myChar, _, myRoot = getParts(LP)
	local _, _, targetRoot = getParts(target)
	if not myChar or not myRoot or not targetRoot then
		setStatus("CHARACTER NOT READY", C.RED)
		return
	end

	-- 纯客户端下安全传送到目标玩家身旁（在非服务端环境下你只能移动自己）
	local ok = pcall(function()
		myChar:PivotTo(targetRoot.CFrame * CFrame.new(3, 0, 0))
		myRoot.AssemblyLinearVelocity = Vector3.zero
	end)
	if ok then
		setStatus("TELEPORTED TO: " .. target.Name, C.GREEN)
	else
		setStatus("TELEPORT FAILED", C.RED)
	end
end

local function flingTarget()
	local target = getTargetPlayer()
	local power = getFlingPower()
	if target and power then
		startClientFling({target}, power)
	end
end

local function flingAll()
	local power = getFlingPower()
	if not power then return end
	local targets = {}
	for _, target in ipairs(Players:GetPlayers()) do
		if target ~= LP then
			table.insert(targets, target)
		end
	end
	startClientFling(targets, power)
end

makeButton(playerCard, "TELEPORT TO TARGET", 0, 145, 0.32, 40, teleportTarget)
makeButton(playerCard, "FLING TARGET", 0.34, 145, 0.32, 40, flingTarget)
makeButton(playerCard, "FLING ALL", 0.68, 145, 0.32, 40, flingAll)

--========================================================
-- MOVEMENT PAGE & ORIGINAL CAMERA FLY ENGINE
--========================================================

local movementCard = createSection(movementPage, "MOVEMENT // CAMERA FLY / SPEED / NOCLIP", 365)

local jumpButton
jumpButton, setJumpState = makeToggle(movementCard, "INFINITE JUMP", 42, function(state)
	infiniteJump = state
	setStatus(state and "INFINITE JUMP ENABLED" or "INFINITE JUMP DISABLED", state and C.GREEN or C.RED)
	return true
end)

local walkInput = makeInput(movementCard, "Walk speed (finite number)", 0, 91, 0.62, 36, "32")

local function applyWalkSpeed()
	local speed = tonumber(walkInput.Text)
	if not validNumber(speed) or speed < 0 or speed > 500 then
		setStatus("INVALID WALK SPEED (0-500)", C.RED)
		return
	end
	local _, humanoid = getParts(LP)
	if not humanoid then
		setStatus("CHARACTER NOT READY", C.RED)
		return
	end
	local ok = pcall(function()
		humanoid.WalkSpeed = speed
	end)
	if ok then
		setStatus("WALK SPEED: " .. tostring(speed), C.GREEN)
	else
		setStatus("FAILED TO SET SPEED", C.RED)
	end
end

makeButton(movementCard, "APPLY WALK SPEED", 0.65, 91, 0.35, 36, applyWalkSpeed)

local flyInput = makeInput(movementCard, "Fly speed (finite number)", 0, 141, 0.62, 36, "80")

local function applyFlySpeed()
	local speed = tonumber(flyInput.Text)
	if not validNumber(speed) or speed < 0 then
		setStatus("INVALID FLY SPEED", C.RED)
		return
	end
	flySpeed = speed
	setStatus("FLY SPEED: " .. tostring(speed), C.GREEN)
end

makeButton(movementCard, "APPLY FLY SPEED", 0.65, 141, 0.35, 36, applyFlySpeed)

-- 原版 LinearVelocity + AlignOrientation 摄像机飞行引擎
local flyAttachment, flyVelocity, flyOrientation, flyConnection, flyHumanoid, oldAutoRotate

local function cleanupFly()
	if flyConnection then
		pcall(function() flyConnection:Disconnect() end)
		flyConnection = nil
	end
	for _, object in ipairs({flyVelocity, flyOrientation, flyAttachment}) do
		if object then
			pcall(function() object:Destroy() end)
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
	local character, humanoid, root = getParts(LP)
	if not character or not humanoid or not root then
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

		local cam = Workspace.CurrentCamera
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
		if not root.Parent or not flyVelocity or not flyVelocity.Parent or not flyOrientation or not flyOrientation.Parent then
			return
		end

		local currentCamera = Workspace.CurrentCamera
		if not currentCamera then return end

		local cameraCFrame = currentCamera.CFrame
		local cameraForward = cameraCFrame.LookVector.Unit
		local cameraRight = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)
		cameraRight = cameraRight.Magnitude > 0.001 and cameraRight.Unit or Vector3.new(1, 0, 0)

		local bodyForward = getBodyForward(root, cameraCFrame)
		pcall(function()
			flyOrientation.CFrame = CFrame.lookAt(Vector3.zero, bodyForward, Vector3.yAxis)
		end)

		local movement = Vector3.zero
		if not UIS:GetFocusedTextBox() then
			if UIS:IsKeyDown(Enum.KeyCode.W) then movement += cameraForward end
			if UIS:IsKeyDown(Enum.KeyCode.S) then movement -= cameraForward end
			if UIS:IsKeyDown(Enum.KeyCode.A) then movement -= cameraRight end
			if UIS:IsKeyDown(Enum.KeyCode.D) then movement += cameraRight end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then movement += Vector3.yAxis end
			if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl) then
				movement -= Vector3.yAxis
			end
		end

		if movement.Magnitude > 1 then
			movement = movement.Unit
		end

		pcall(function()
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

local noclipButton
noclipButton, setNoclipState = makeToggle(movementCard, "NOCLIP / 穿墙", 241, applyNoclip)

local invisibleButton
invisibleButton, setInvisibleState = makeToggle(movementCard, "INVISIBILITY / 隐身", 291, applyInvisible)

--========================================================
-- INFINITE JUMP & RESPAWN LIFECYCLE
--========================================================

UIS.JumpRequest:Connect(function()
	if not infiniteJump then return end
	pcall(function()
		local _, humanoid = getParts(LP)
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
end)

LP.CharacterRemoving:Connect(function()
	cleanupFly()
	restoreNoclip()
	restoreInvisible()
end)

LP.CharacterAdded:Connect(function()
	task.wait(0.35)
	if flyEnabled and not setupFly() then
		flyEnabled = false
		setFlyState(false, true)
	end
	if noclipEnabled then
		applyNoclip(true)
	end
	if invisibleEnabled then
		applyInvisible(true)
	end
end)

--========================================================
-- ESP SYSTEM (完整还原 Highlight + Box + Name + 血条)
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

	local character, humanoid, root = getParts(player)
	if not character or not humanoid or not root then return end

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
		}, character)
		table.insert(objects, highlight)

		local box = create("BoxHandleAdornment", {
			Name = "EV03_Box",
			Adornee = root,
			Size = Vector3.new(4, 6, 2),
			CFrame = CFrame.new(0, 1.5, 0),
			Color3 = C.RED,
			Transparency = 0.25,
			AlwaysOnTop = true,
			ZIndex = 10,
		}, root)
		table.insert(objects, box)

		local billboard = create("BillboardGui", {
			Name = "EV03_Info",
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
			if not fill.Parent then return end
			local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			fill.Size = UDim2.fromScale(ratio, 1)
			fill.BackgroundColor3 = ratio > 0.5 and C.GREEN or C.RED
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
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(player)
	removeESP(player)
	local connections = playerConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			pcall(function() connection:Disconnect() end)
		end
		playerConnections[player] = nil
	end
end)

--========================================================
-- ALL 12 FEATURE HANDLERS (100% 还原)
--========================================================

local handlers = {}

handlers.TeleportTarget = teleportTarget
handlers.FlingTarget = flingTarget
handlers.FlingAll = flingAll
handlers.InfiniteJump = function() setJumpState(not infiniteJump) end
handlers.ApplyWalkSpeed = applyWalkSpeed
handlers.Fly = function() setFlyState(not flyEnabled) end
handlers.ApplyFlySpeed = applyFlySpeed
handlers.Noclip = function() setNoclipState(not noclipEnabled) end
handlers.ESP = function() setESPState(not espEnabled) end
handlers.Invisible = function() setInvisibleState(not invisibleEnabled) end
handlers.ToggleMenu = function() gui.Enabled = not gui.Enabled end

handlers.Panic = function()
	if activeFlingSession then
		finishFling(activeFlingSession)
	end
	setJumpState(false)
	setFlyState(false)
	setESPState(false)
	setNoclipState(false)
	setInvisibleState(false)

	walkInput.Text = "16"
	local _, humanoid = getParts(LP)
	if humanoid then
		pcall(function() humanoid.WalkSpeed = 16 end)
	end
	setStatus("PANIC RESET COMPLETE", C.RED)
end

--========================================================
-- HOTKEY GROUP (全部 12 个快捷键完整保留)
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
	bindButton = makeButton(hotkeyCard, bindings[action].Name, 0.63, y, 0.34, 32, function()
		listeningAction = action
		bindButton.Text = "PRESS KEY..."
		bindButton.BackgroundColor3 = C.GREEN
		setStatus("REBINDING: " .. label, C.YELLOW)
	end)

	bindButtons[action] = bindButton
end

makeButton(hotkeyCard, "PANIC // DISABLE ALL", 0, 555, 1, 30, handlers.Panic)

--========================================================
-- ABOUT / IDENTITY PAGE
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
-- DEFAULT PAGE
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
-- WINDOW DRAG & MINIMIZE / HIDE
--========================================================

local dragging = false
local dragStart
local startPosition
local dragInput

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
-- ALL CUSTOM HOTKEYS (兼容 Roblox Studio & 外部执行器)
--========================================================

UIS.InputBegan:Connect(function(input, processed)
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
	-- 注意：只拦截正在输入文字的文本框，不再被 Studio 自身的 processed 标志误拦截
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

--========================================================
-- READY
--========================================================

refreshBindingLabels()
setStatus("EV03 CAMERA FLY V3.8 STANDALONE READY", C.GREEN)
print("[EV03 CONTROL V3.8] STANDALONE READY - ALL 12 HOTKEYS ACTIVE")
