--========================================================
-- EV03 CONTROL V3.8 - EXECUTOR STANDALONE EDITION
-- 原作者: 阿叶ev03
-- 纯客户端本地实现 / 无 RemoteEvent / 无服务端依赖
-- 适配: loadstring(game:HttpGet("你的网址"))()
--========================================================

local SUCCESS, FATAL_ERROR = pcall(function()

	--====================================================
	-- 环境等待
	--====================================================
	if not game:IsLoaded() then
		pcall(function()
			game.Loaded:Wait()
		end)
	end

	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")

	local LP = Players.LocalPlayer
	if not LP then
		warn("[EV03] LocalPlayer not found")
		return
	end

	local PG = LP:WaitForChild("PlayerGui", 15)
	if not PG then
		warn("[EV03] PlayerGui not found")
		return
	end

	--====================================================
	-- 安全工具
	--====================================================
	local function safeCall(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[EV03 SAFE]", tostring(err))
		end
		return ok, err
	end

	local function validNumber(n)
		return typeof(n) == "number"
			and n == n
			and n ~= math.huge
			and n ~= -math.huge
	end

	--====================================================
	-- 清理旧 GUI
	--====================================================
	for _, name in ipairs({"EV03_CONTROL", "EV03_ESP"}) do
		local old = PG:FindFirstChild(name)
		if old then
			safeCall(function()
				old:Destroy()
			end)
		end
	end

	--====================================================
	-- 本地动作核心
	--====================================================
	local function getParts(player)
		if not player then
			return nil
		end

		local character = player.Character
		if not character then
			return nil
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root or humanoid.Health <= 0 then
			return nil
		end

		return character, humanoid, root
	end

	-- 精确用户名优先，否则接受唯一前缀匹配
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

	--====================================================
	-- 本地 NOCLIP
	--====================================================
	local noclipActive = false
	local noclipSession = nil

	local function restoreNoclip()
		local session = noclipSession
		noclipSession = nil

		if not session then
			return
		end

		if session.connection then
			safeCall(function()
				session.connection:Disconnect()
			end)
		end

		for part, original in pairs(session.parts) do
			if part and part.Parent then
				safeCall(function()
					part.CanCollide = original
				end)
			end
		end
	end

	local function applyNoclip(enabled)
		if typeof(enabled) ~= "boolean" then
			return false, "INVALID NOCLIP STATE"
		end

		if not enabled then
			noclipActive = false
			restoreNoclip()
			return true, "NOCLIP DISABLED"
		end

		local character = LP.Character
		if not character then
			return false, "CHARACTER NOT READY"
		end

		noclipActive = true
		restoreNoclip()

		local session = {
			character = character,
			parts = {},
			connection = nil,
		}

		noclipSession = session

		local function enforce(object)
			if not object:IsA("BasePart") then
				return
			end
			if not object:IsDescendantOf(character) then
				return
			end

			if session.parts[object] == nil then
				session.parts[object] = object.CanCollide
			end

			safeCall(function()
				object.CanCollide = false
			end)
		end

		for _, object in ipairs(character:GetDescendants()) do
			enforce(object)
		end

		session.connection = RunService.PreSimulation:Connect(function()
			if noclipSession ~= session then
				return
			end

			local current = LP.Character
			if current ~= character then
				return
			end

			for _, object in ipairs(character:GetDescendants()) do
				enforce(object)
			end
		end)

		return true, "NOCLIP ENABLED"
	end

	--====================================================
	-- 本地 INVISIBILITY
	--====================================================
	local invisibleActive = false
	local invisibleSession = nil

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

	local function hideObject(session, object)
		if not object:IsDescendantOf(session.character) then
			return
		end

		local property, original = getHiddenProperty(object)
		if not property then
			return
		end

		if session.props[object] == nil then
			session.props[object] = {
				property = property,
				original = original,
			}
		end

		safeCall(function()
			object[property] = property == "Transparency" and 1 or false
		end)
	end

	local function restoreInvisible()
		local session = invisibleSession
		invisibleSession = nil

		if not session then
			return
		end

		if session.connection then
			safeCall(function()
				session.connection:Disconnect()
			end)
		end

		for object, data in pairs(session.props) do
			if object and object.Parent then
				safeCall(function()
					object[data.property] = data.original
				end)
			end
		end

		local humanoid = session.humanoid
		if humanoid and humanoid.Parent then
			safeCall(function()
				humanoid.DisplayDistanceType = session.displayDistanceType
			end)
		end
	end

	local function applyInvisible(enabled)
		if typeof(enabled) ~= "boolean" then
			return false, "INVALID INVISIBILITY STATE"
		end

		if not enabled then
			invisibleActive = false
			restoreInvisible()
			return true, "INVISIBILITY DISABLED"
		end

		local character = LP.Character
		if not character then
			return false, "CHARACTER NOT READY"
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return false, "HUMANOID NOT READY"
		end

		invisibleActive = true
		restoreInvisible()

		local session = {
			character = character,
			humanoid = humanoid,
			displayDistanceType = humanoid.DisplayDistanceType,
			props = {},
			connection = nil,
		}

		invisibleSession = session

		safeCall(function()
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

			for _, object in ipairs(character:GetDescendants()) do
				hideObject(session, object)
			end
		end)

		session.connection = RunService.PreSimulation:Connect(function()
			if invisibleSession ~= session then
				return
			end

			local current = LP.Character
			if current ~= character then
				return
			end

			for object, data in pairs(session.props) do
				if object and object.Parent then
					safeCall(function()
						object[data.property] =
							data.property == "Transparency" and 1 or false
					end)
				end
			end

			if humanoid.Parent then
				safeCall(function()
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end)
			end
		end)

		return true, "INVISIBILITY ENABLED"
	end

	--====================================================
	-- 本地 FLING
	--====================================================
	local FLING_MIN_POWER = 1
	local FLING_MAX_POWER = 10
	local FLING_ORBIT_RADIUS = 6
	local activeFlingSessions = {}

	local function destroyFlingMovers(session)
		for _, mover in ipairs(session.movers or {}) do
			if mover and mover.Parent then
				safeCall(function()
					mover:Destroy()
				end)
			end
		end
		session.movers = {}
	end

	local function finishFling(admin, session)
		if activeFlingSessions[admin] == session then
			activeFlingSessions[admin] = nil
		end

		destroyFlingMovers(session)

		local character = session.character
		if character and character.Parent and admin.Character == character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")

			safeCall(function()
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

	local function tryFlingTargetImpulse(target, power)
		local targetCharacter, targetHumanoid, targetRoot = getParts(target)
		if not targetCharacter or not targetHumanoid or not targetRoot then
			return false
		end

		local mass = targetRoot.AssemblyMass
		if not validNumber(mass) or mass <= 0 then
			mass = 1
		end

		safeCall(function()
			targetRoot:ApplyImpulse(
				Vector3.new(
					math.random(-150, 150),
					500 + power * 60,
					math.random(-150, 150)
				) * mass
			)
		end)

		safeCall(function()
			targetRoot.AssemblyAngularVelocity = Vector3.new(
				600 + power * 80,
				600 + power * 80,
				600 + power * 80
			)
		end)

		safeCall(function()
			targetRoot.AssemblyLinearVelocity =
				targetRoot.AssemblyLinearVelocity
				+ Vector3.new(0, 250 + power * 40, 0)
		end)

		local started = os.clock()
		local connection

		connection = RunService.Heartbeat:Connect(function()
			if os.clock() - started > 0.8
				or not targetRoot.Parent
				or not targetHumanoid.Parent then
				if connection then
					safeCall(function()
						connection:Disconnect()
					end)
				end
				connection = nil
				return
			end

			safeCall(function()
				targetRoot.AssemblyAngularVelocity = Vector3.new(
					500 + power * 60,
					500 + power * 60,
					500 + power * 60
				)
			end)

			safeCall(function()
				targetRoot.AssemblyLinearVelocity = Vector3.new(
					targetRoot.AssemblyLinearVelocity.X,
					math.max(
						targetRoot.AssemblyLinearVelocity.Y,
						150 + power * 25
					),
					targetRoot.AssemblyLinearVelocity.Z
				)
			end)
		end)

		task.delay(1.0, function()
			if connection then
				safeCall(function()
					connection:Disconnect()
				end)
			end
		end)

		safeCall(function()
			targetHumanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end)

		return true
	end

	local function flingTarget(admin, target, power, session)
		local character, humanoid, root = getParts(admin)
		local targetCharacter, _, targetRoot = getParts(target)

		if not character or not humanoid or not root then
			return false
		end

		if not targetCharacter or not targetRoot or targetRoot.Anchored then
			return false
		end

		local offset = root.Position - targetRoot.Position
		local horizontal = Vector3.new(offset.X, 0, offset.Z)

		if horizontal.Magnitude < 0.01 then
			horizontal = Vector3.new(
				root.CFrame.LookVector.X,
				0,
				root.CFrame.LookVector.Z
			)
		end

		if horizontal.Magnitude < 0.01 then
			horizontal = Vector3.new(1, 0, 0)
		else
			horizontal = horizontal.Unit
		end

		local startPosition = targetRoot.Position + horizontal * FLING_ORBIT_RADIUS
		local facingTarget = CFrame.lookAt(startPosition, targetRoot.Position)

		safeCall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(facingTarget)
		end)

		local orbitDuration = math.clamp(1.2 - power * 0.07, 0.6, 1.1)
		local orbitStarted = os.clock()

		while os.clock() - orbitStarted < orbitDuration do
			RunService.Heartbeat:Wait()

			if activeFlingSessions[admin] ~= session then
				return false
			end

			if admin.Character ~= character
				or target.Character ~= targetCharacter
				or not targetRoot.Parent
				or not root.Parent then
				return false
			end

			local progress = math.clamp(
				(os.clock() - orbitStarted) / orbitDuration,
				0,
				1
			)
			local angle = progress * math.pi * 2
			local orbitOffset = horizontal * (math.cos(angle) * FLING_ORBIT_RADIUS)
				+ Vector3.yAxis * (math.sin(angle) * FLING_ORBIT_RADIUS)

			safeCall(function()
				character:PivotTo(CFrame.new(targetRoot.Position + orbitOffset))
			end)
		end

		if activeFlingSessions[admin] ~= session then
			return false
		end

		if target.Character ~= targetCharacter or not targetRoot.Parent then
			return false
		end

		return tryFlingTargetImpulse(target, power)
	end

	local function startFling(admin, targets, power)
		if not validNumber(power)
			or power < FLING_MIN_POWER
			or power > FLING_MAX_POWER
			or power % 1 ~= 0 then
			return false, "INVALID FLING POWER (1-10)"
		end

		if activeFlingSessions[admin] then
			return false, "FLING ALREADY ACTIVE"
		end

		local character, humanoid, root = getParts(admin)
		if not character or not humanoid or not root then
			return false, "CHARACTER NOT READY"
		end

		local validTargets = {}
		for _, target in ipairs(targets) do
			if target and target ~= admin and target.Parent == Players then
				local targetCharacter = target.Character
				if targetCharacter
					and targetCharacter:FindFirstChild("HumanoidRootPart") then
					table.insert(validTargets, target)
				end
			end
		end

		if #validTargets == 0 then
			return false, "NO VALID TARGETS"
		end

		local session = {
			character = character,
			savedPivot = character:GetPivot(),
			oldAutoRotate = humanoid.AutoRotate,
			movers = {},
		}

		activeFlingSessions[admin] = session

		task.spawn(function()
			safeCall(function()
				humanoid.AutoRotate = false
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)

				for _, target in ipairs(validTargets) do
					if activeFlingSessions[admin] ~= session then
						break
					end

					if admin.Character ~= character
						or not character.Parent
						or humanoid.Health <= 0 then
						break
					end

					flingTarget(admin, target, power, session)
				end
			end)

			finishFling(admin, session)
		end)

		return true, "LOCAL FLING STARTED // POWER " .. tostring(power)
	end

	--====================================================
	-- 本地 TELEPORT
	--====================================================
	local function teleportTargetLocal(targetName)
		local target, findError = findTarget(targetName)
		if not target then
			return false, findError or "PLAYER NOT FOUND"
		end

		if target == LP then
			return false, "CANNOT TARGET YOURSELF"
		end

		local _, _, adminRoot = getParts(LP)
		local targetCharacter, _, targetRoot = getParts(target)

		if not adminRoot or not targetCharacter or not targetRoot then
			return false, "CHARACTER NOT READY"
		end

		local destination = adminRoot.CFrame * CFrame.new(4, 0, 0)

		task.spawn(function()
			local started = os.clock()
			local connection

			connection = RunService.Heartbeat:Connect(function()
				if os.clock() - started > 0.6
					or not targetRoot.Parent
					or not targetCharacter.Parent then
					if connection then
						safeCall(function()
							connection:Disconnect()
						end)
					end
					connection = nil
					return
				end

				safeCall(function()
					targetCharacter:PivotTo(destination)
					targetRoot.AssemblyLinearVelocity = Vector3.zero
				end)
			end)

			task.wait(0.7)

			if connection then
				safeCall(function()
					connection:Disconnect()
				end)
			end
		end)

		return true, "PLAYER TELEPORTED: " .. target.Name
	end

	--====================================================
	-- 本地 SPEED / PANIC
	--====================================================
	local function setSpeedLocal(argument)
		local _, humanoid = getParts(LP)
		local speed = tonumber(argument)

		if not humanoid then
			return false, "CHARACTER NOT READY"
		end

		if not validNumber(speed) or speed < 0 or speed > 500 then
			return false, "INVALID SPEED (0-500)"
		end

		local ok = safeCall(function()
			humanoid.WalkSpeed = speed
		end)

		if not ok then
			return false, "ENGINE REJECTED SPEED"
		end

		return true, "WALK SPEED: " .. tostring(speed)
	end

	local function panicResetLocal()
		local session = activeFlingSessions[LP]
		if session then
			finishFling(LP, session)
		end

		applyNoclip(false)
		applyInvisible(false)

		local _, humanoid = getParts(LP)
		if humanoid then
			safeCall(function()
				humanoid.WalkSpeed = 16
			end)
		end

		return true, "PANIC RESET COMPLETE"
	end

	--====================================================
	-- 颜色
	--====================================================
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

	local function create(className, props, parent)
		local obj = Instance.new(className)

		for key, value in pairs(props or {}) do
			pcall(function()
				obj[key] = value
			end)
		end

		obj.Parent = parent
		return obj
	end

	--====================================================
	-- 窗口尺寸
	--====================================================
	local camera = workspace.CurrentCamera
	local viewport = (camera and camera.ViewportSize) or Vector2.new(1280, 720)

	local windowWidth = math.floor(math.clamp(viewport.X - 30, 560, 900))
	local windowHeight = math.floor(math.clamp(viewport.Y - 40, 440, 680))

	--====================================================
	-- GUI
	--====================================================
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

	--====================================================
	-- HEADER
	--====================================================
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

	--====================================================
	-- MAIN BODY
	--====================================================
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
		status.Text = tostring(message)
		status.TextColor3 = color or C.GREEN
	end

	--====================================================
	-- 本地动作派发
	--====================================================
	local localActions = {
		SetSpeed = setSpeedLocal,
		SetNoclip = function(argument)
			return applyNoclip(argument)
		end,
		SetInvisible = function(argument)
			return applyInvisible(argument)
		end,
		TeleportTarget = teleportTargetLocal,
		FlingTarget = function(argument)
			local targetName, power

			if typeof(argument) == "string" then
				targetName, power = argument, 10
			elseif typeof(argument) == "table" then
				targetName, power = argument.target, argument.power
			end

			local target, findError = findTarget(targetName)
			if not target then
				return false, findError or "PLAYER NOT FOUND"
			end

			if target == LP then
				return false, "CANNOT TARGET YOURSELF"
			end

			return startFling(LP, {target}, power)
		end,
		FlingAll = function(power)
			local targets = {}
			for _, target in ipairs(Players:GetPlayers()) do
				if target ~= LP then
					table.insert(targets, target)
				end
			end
			return startFling(LP, targets, power)
		end,
		PanicReset = panicResetLocal,
	}

	local function runLocalAction(action, argument, callback)
		local fn = localActions[action]

		if not fn then
			setStatus("UNKNOWN ACTION", C.RED)
			if callback then
				safeCall(callback, false, "UNKNOWN ACTION")
			end
			return false
		end

		local ok, success, message = pcall(fn, argument)

		if not ok then
			warn("[EV03 LOCAL ERROR]", success)
			setStatus("LOCAL ACTION ERROR", C.RED)
			if callback then
				safeCall(callback, false, "LOCAL ERROR")
			end
			return false
		end

		local passed = success == true
		setStatus(tostring(message or "ACTION COMPLETE"), passed and C.GREEN or C.RED)

		if callback then
			safeCall(callback, passed, message)
		end

		return passed
	end

	--====================================================
	-- PAGE SYSTEM
	--====================================================
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

	--====================================================
	-- BUTTON HELPERS
	--====================================================
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

	--====================================================
	-- TOGGLE HELPER
	--====================================================
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

	--====================================================
	-- NAVIGATION
	--====================================================
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

	--====================================================
	-- PAGES
	--====================================================
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

	--====================================================
	-- SHARED STATES
	--====================================================
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

	--====================================================
	-- DASHBOARD
	--====================================================
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
		Text = "Creator: 阿叶ev03\nVersion: V3.8\nExecutor Standalone Edition\nNo Server / No Remote Required",
		TextColor3 = C.GRAY,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, dashboardCard)

	--====================================================
	-- PLAYER PAGE
	--====================================================
	local playerCard = createSection(playerPage, "PLAYER // MANAGEMENT", 205)
	local targetInput = makeInput(
		playerCard,
		"Enter exact Roblox Username...",
		0, 39, 1, 36, ""
	)

	local flingPower = 10

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

	local flingPowerLabel = create("TextLabel", {
		Size = UDim2.new(0.18, 0, 0, 32),
		Position = UDim2.new(0.29, 0, 0, 82),
		BackgroundColor3 = C.PANEL2,
		Text = tostring(flingPower),
		TextColor3 = C.WHITE,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		BorderSizePixel = 0,
	}, playerCard)
	create("UICorner", {CornerRadius = UDim.new(0, 6)}, flingPowerLabel)

	local function updateFlingPower(delta)
		flingPower = math.clamp(flingPower + delta, 1, 10)
		flingPowerLabel.Text = tostring(flingPower)
	end

	makeButton(playerCard, "−", 0.49, 82, 0.1, 32, function()
		updateFlingPower(-1)
	end)
	makeButton(playerCard, "+", 0.61, 82, 0.1, 32, function()
		updateFlingPower(1)
	end)

	create("TextLabel", {
		Size = UDim2.new(0.27, -4, 0, 30),
		Position = UDim2.new(0.73, 4, 0, 83),
		BackgroundTransparency = 1,
		Text = "数值越大，转速和击飞力越强",
		TextColor3 = C.GRAY,
		TextSize = 9,
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

	local function teleportTarget()
		local name = getTarget()
		if name then
			runLocalAction("TeleportTarget", name)
		end
	end

	local function flingTarget()
		local name = getTarget()
		if name then
			runLocalAction("FlingTarget", {target = name, power = flingPower})
		end
	end

	local function flingAll()
		runLocalAction("FlingAll", flingPower)
	end

	makeButton(playerCard, "TELEPORT TO ME", 0, 145, 0.32, 40, teleportTarget)
	makeButton(playerCard, "FLING TARGET", 0.34, 145, 0.32, 40, flingTarget)
	makeButton(playerCard, "FLING ALL", 0.68, 145, 0.32, 40, flingAll)

	--====================================================
	-- MOVEMENT PAGE
	--====================================================
	local movementCard = createSection(
		movementPage,
		"MOVEMENT // CAMERA FLY / SPEED / NOCLIP",
		365
	)

	local jumpButton
	jumpButton, setJumpState = makeToggle(movementCard, "INFINITE JUMP", 42, function(state)
		infiniteJump = state
		return true
	end)

	local walkInput = makeInput(
		movementCard,
		"Walk speed (finite number)",
		0, 91, 0.62, 36, "32"
	)

	local function applyWalkSpeed()
		local speed = tonumber(walkInput.Text)
		if not validNumber(speed) or speed < 0 then
			setStatus("INVALID WALK SPEED", C.RED)
			return
		end
		runLocalAction("SetSpeed", speed)
	end

	makeButton(movementCard, "APPLY WALK SPEED", 0.65, 91, 0.35, 36, applyWalkSpeed)

	local flyInput = makeInput(
		movementCard,
		"Fly speed (finite number)",
		0, 141, 0.62, 36, "80"
	)

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

	--====================================================
	-- CAMERA DIRECTION FLY ENGINE (客户端原本实现，保留)
	--====================================================
	local flyAttachment
	local flyVelocity
	local flyOrientation
	local flyConnection
	local flyHumanoid
	local oldAutoRotate

	local function cleanupFly()
		if flyConnection then
			safeCall(function()
				flyConnection:Disconnect()
			end)
			flyConnection = nil
		end

		for _, object in ipairs({flyVelocity, flyOrientation, flyAttachment}) do
			if object then
				safeCall(function()
					object:Destroy()
				end)
			end
		end

		flyVelocity = nil
		flyOrientation = nil
		flyAttachment = nil

		if flyHumanoid and flyHumanoid.Parent then
			safeCall(function()
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

			if not root.Parent
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
			safeCall(function()
				flyOrientation.CFrame = CFrame.lookAt(Vector3.zero, bodyForward, Vector3.yAxis)
			end)

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

			safeCall(function()
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
	noclipButton, setNoclipState = makeToggle(movementCard, "NOCLIP / 穿墙", 241, function(state)
		noclipEnabled = state
		local previous = not state

		local sent = runLocalAction("SetNoclip", state, function(success, message)
			if not success then
				noclipEnabled = previous
				setNoclipState(previous, true)
				setStatus(message, C.RED)
			end
		end)

		return sent
	end)

	local invisibleButton
	invisibleButton, setInvisibleState = makeToggle(movementCard, "INVISIBILITY / 隐身", 291, function(state)
		invisibleEnabled = state
		local previous = not state

		local sent = runLocalAction("SetInvisible", state, function(success, message)
			if not success then
				invisibleEnabled = previous
				setInvisibleState(previous, true)
				setStatus(message, C.RED)
			end
		end)

		return sent
	end)

	--====================================================
	-- INFINITE JUMP + RESPAWN
	--====================================================
	UIS.JumpRequest:Connect(function()
		if not infiniteJump then return end

		safeCall(function()
			local character = LP.Character
			if not character then return end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end)

	LP.CharacterRemoving:Connect(function()
		safeCall(cleanupFly)
		safeCall(restoreNoclip)
		safeCall(restoreInvisible)
	end)

	LP.CharacterAdded:Connect(function()
		task.wait(0.5)

		if flyEnabled and not setupFly() then
			flyEnabled = false
			if setFlyState then
				setFlyState(false, true)
			end
		end

		task.wait(0.2)

		if noclipActive then
			applyNoclip(true)
		end

		if invisibleActive then
			applyInvisible(true)
		end
	end)

	--====================================================
	-- ESP（原本就是本地实现，保留并加固）
	--====================================================
	local espCard = createSection(espPage, "ESP // VISUAL SYSTEM", 145)
	local espObjects = {}
	local playerConnections = {}

	local function cleanupESP(data)
		if not data then return end

		for _, connection in ipairs(data.connections or {}) do
			safeCall(function()
				connection:Disconnect()
			end)
		end

		for _, object in ipairs(data.objects or {}) do
			safeCall(function()
				object:Destroy()
			end)
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

				local ratio = math.clamp(
					humanoid.Health / math.max(humanoid.MaxHealth, 1),
					0,
					1
				)

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
			return true
		end

		for _, player in ipairs(Players:GetPlayers()) do
			createESP(player)
		end

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
				safeCall(function()
					connection:Disconnect()
				end)
			end
			playerConnections[player] = nil
		end
	end)

	--====================================================
	-- FEATURE HANDLERS
	--====================================================
	local handlers = {}

	handlers.TeleportTarget = teleportTarget
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
		setJumpState(false)
		setFlyState(false)
		setESPState(false)
		setNoclipState(false, true)
		setInvisibleState(false, true)

		noclipEnabled = false
		invisibleEnabled = false
		walkInput.Text = "16"

		runLocalAction("PanicReset")
		setStatus("PANIC RESET REQUESTED", C.RED)
	end

	--====================================================
	-- HOTKEY GROUP
	--====================================================
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
		gui.Enabled = not gui.Enabled
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
			button.Text = bindings[action] and bindings[action].Name or "UNBOUND"
			button.BackgroundColor3 = C.DARK_RED
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

	--====================================================
	-- ABOUT / IDENTITY
	--====================================================
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
			"项目类型：Roblox Studio 管理面板",
			"运行模式：EXECUTOR STANDALONE",
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

	--====================================================
	-- DEFAULT PAGE
	--====================================================
	local function selectPage(name)
		if not pages[name] then return end

		for pageName, page in pairs(pages) do
			page.Visible = pageName == name
		end

		for pageName, button in pairs(navButtons) do
			local selected = pageName == name
			button.BackgroundColor3 = selected and C.DARK_RED or C.SIDEBAR
			button.TextColor3 = selected and C.WHITE or C.GRAY
		end
	end

	selectPage("DASHBOARD")

	--====================================================
	-- WINDOW DRAG
	--====================================================
	local dragging = false
	local dragStart
	local startPosition
	local dragInput

	dragArea.InputBegan:Connect(function(input)
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

	dragArea.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
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

	--====================================================
	-- MINIMIZE / HIDE
	--====================================================
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

	--====================================================
	-- ALL CUSTOM HOTKEYS
	--====================================================
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

	--====================================================
	-- CLEANUP
	--====================================================
	safeCall(function()
		script.Destroying:Connect(function()
			flyEnabled = false
			safeCall(cleanupFly)

			for player in pairs(espObjects) do
				removeESP(player)
			end

			for _, connections in pairs(playerConnections) do
				for _, connection in ipairs(connections) do
					safeCall(function()
						connection:Disconnect()
					end)
				end
			end

			safeCall(restoreNoclip)
			safeCall(restoreInvisible)

			if espGui then
				safeCall(function()
					espGui:Destroy()
				end)
			end

			if gui then
				safeCall(function()
					gui:Destroy()
				end)
			end
		end)
	end)

	--====================================================
	-- READY
	--====================================================
	refreshBindingLabels()
	setStatus("EV03 STANDALONE V3.8 READY", C.GREEN)

	print("======================================")
	print(" EV03 CONTROL V3.8")
	print(" MODE: EXECUTOR STANDALONE")
	print(" CREATOR: 阿叶ev03")
	print(" CAMERA DIRECTION FLY: READY")
	print(" PREFIX PLAYER TARGETING: READY")
	print(" LOCAL NOCLIP / INVISIBLE: READY")
	print(" LOCAL FLING / TELEPORT: READY")
	print(" W = CAMERA FORWARD")
	print(" S = CAMERA BACKWARD")
	print(" A / D = CAMERA SIDEWAYS")
	print(" SPACE / CTRL = VERTICAL")
	print(" HOTKEY DEFAULT: F")
	print("======================================")
end)

if not SUCCESS then
	warn("[EV03] FATAL ERROR:", tostring(FATAL_ERROR))
end
