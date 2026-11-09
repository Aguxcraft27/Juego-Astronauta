--!nonstrict
-- Controles de sigilo y HUD del astronauta.
--   Shift (mantener)      -> Correr
--   C / Ctrl (alternar)   -> Agacharse
--   F                     -> Linterna
-- El servidor es quien aplica WalkSpeed y la linterna (PlayerStateService); aquí solo se piden los cambios.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local AlienConfig = require(Shared:WaitForChild("AlienConfig"))

local AstronautController = {}

local player = Players.LocalPlayer
local runtime: Folder
local setMoveModeRemote: RemoteEvent
local toggleFlashlightRemote: RemoteEvent

local runHeld = false
local crouched = false
local currentMode = Types.MoveMode.Walk
local lastSuspicion = 0

-- Movimiento ------------------------------------------------------------------------
local function desiredMode(): string
	if runHeld then
		return Types.MoveMode.Run
	elseif crouched then
		return Types.MoveMode.Crouch
	end
	return Types.MoveMode.Walk
end

local function applyCameraOffset(mode: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local offset = mode == Types.MoveMode.Crouch and AlienConfig.Player.CrouchCameraOffset or 0
		TweenService:Create(humanoid, TweenInfo.new(0.2), { CameraOffset = Vector3.new(0, offset, 0) }):Play()
	end
end

local function refreshMode()
	local mode = desiredMode()
	if mode ~= currentMode then
		currentMode = mode
		setMoveModeRemote:FireServer(mode)
		applyCameraOffset(mode)
	end
end

local RUN_KEYS = { [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.RightShift] = true }
local CROUCH_KEYS = { [Enum.KeyCode.C] = true, [Enum.KeyCode.LeftControl] = true }

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if RUN_KEYS[input.KeyCode] then
		runHeld = true
		refreshMode()
	elseif CROUCH_KEYS[input.KeyCode] then
		crouched = not crouched
		refreshMode()
	elseif input.KeyCode == Enum.KeyCode.F then
		toggleFlashlightRemote:FireServer()
	end
end

local function onInputEnded(input: InputObject)
	if RUN_KEYS[input.KeyCode] then
		runHeld = false
		refreshMode()
	end
end

-- HUD ---------------------------------------------------------------------------------
local STATUS_TEXT = {
	[Types.StationStatus.Desapercibido] = { "DESAPERCIBIDO (OCULTO)", Color3.fromRGB(120, 220, 140) },
	[Types.StationStatus.Sospecha] = { "INVESTIGANDO RUIDO / ZONA", Color3.fromRGB(240, 200, 60) },
	[Types.StationStatus.Advertencia] = { "¡TE HA VISTO! ESCÓNDETE YA", Color3.fromRGB(255, 90, 60) },
	[Types.StationStatus.CorriendoAlarma] = { "¡INTRUSO CONFIRMADO! CORRIENDO A LA ALARMA", Color3.fromRGB(255, 130, 40) },
	[Types.StationStatus.AlertaRoja] = { "¡ALERTA ROJA! CACERÍA ACTIVA", Color3.fromRGB(255, 40, 40) },
}

local hud = {}

local function createHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AstronautaHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	-- Panel Superior de Sospecha
	local frame = Instance.new("Frame")
	frame.Name = "SuspicionPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 20)
	frame.Size = UDim2.fromOffset(380, 80)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, 0, 0, 22)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextSize = 17
	status.TextStrokeTransparency = 0.4
	status.Text = "DESAPERCIBIDO"
	status.TextColor3 = STATUS_TEXT[Types.StationStatus.Desapercibido][2]
	status.Parent = frame

	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack"
	barBack.Position = UDim2.new(0, 0, 0, 26)
	barBack.Size = UDim2.new(1, 0, 0, 16)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	barBack.BackgroundTransparency = 0.25
	barBack.BorderSizePixel = 0
	barBack.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = barBack

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(240, 200, 60)
	fill.BorderSizePixel = 0
	fill.Parent = barBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local percent = Instance.new("TextLabel")
	percent.Name = "Percent"
	percent.Size = UDim2.new(1, 0, 1, 0)
	percent.BackgroundTransparency = 1
	percent.Font = Enum.Font.GothamMedium
	percent.TextSize = 12
	percent.TextColor3 = Color3.new(1, 1, 1)
	percent.Text = "0% SOSPECHA"
	percent.ZIndex = 2
	percent.Parent = barBack

	-- Aviso de detección (¡El alien te está viendo!)
	local sightWarning = Instance.new("TextLabel")
	sightWarning.Name = "SightWarning"
	sightWarning.Position = UDim2.new(0, 0, 0, 46)
	sightWarning.Size = UDim2.new(1, 0, 0, 24)
	sightWarning.BackgroundTransparency = 1
	sightWarning.Font = Enum.Font.GothamBlack
	sightWarning.TextSize = 14
	sightWarning.TextColor3 = Color3.fromRGB(255, 60, 60)
	sightWarning.TextStrokeTransparency = 0.3
	sightWarning.Text = "⚠️ ¡EN LÍNEA DE VISIÓN! ¡AGÁCHATE [C] O ESCÓNDETE EN ARMARIO [E]!"
	sightWarning.Visible = false
	sightWarning.Parent = frame

	-- Guía de Objetivos y Controles (Arriba a la Izquierda)
	local guideFrame = Instance.new("Frame")
	guideFrame.Name = "GuideFrame"
	guideFrame.Position = UDim2.new(0, 20, 0, 20)
	guideFrame.Size = UDim2.fromOffset(310, 175)
	guideFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	guideFrame.BackgroundTransparency = 0.35
	guideFrame.BorderSizePixel = 0
	guideFrame.Parent = gui
	local guideCorner = Instance.new("UICorner")
	guideCorner.CornerRadius = UDim.new(0, 6)
	guideCorner.Parent = guideFrame

	local guideTitle = Instance.new("TextLabel")
	guideTitle.Name = "Title"
	guideTitle.Position = UDim2.new(0, 10, 0, 6)
	guideTitle.Size = UDim2.new(1, -20, 0, 20)
	guideTitle.BackgroundTransparency = 1
	guideTitle.Font = Enum.Font.GothamBold
	guideTitle.TextSize = 13
	guideTitle.TextColor3 = Color3.fromRGB(255, 190, 80)
	guideTitle.TextXAlignment = Enum.TextXAlignment.Left
	guideTitle.Text = "MISIÓN: ESCAPAR DE LA ESTACIÓN"
	guideTitle.Parent = guideFrame

	local guideBody = Instance.new("TextLabel")
	guideBody.Name = "Body"
	guideBody.Position = UDim2.new(0, 10, 0, 28)
	guideBody.Size = UDim2.new(1, -20, 1, -34)
	guideBody.BackgroundTransparency = 1
	guideBody.Font = Enum.Font.Code
	guideBody.TextSize = 11
	guideBody.TextColor3 = Color3.fromRGB(215, 225, 235)
	guideBody.TextXAlignment = Enum.TextXAlignment.Left
	guideBody.TextYAlignment = Enum.TextYAlignment.Top
	guideBody.TextWrapped = true
	guideBody.Text = "• OBJETIVO: Cruza la estación, desactiva la alarma en la Consola CRT (Sala B) y huye.\n• [C] Agacharse: Vital para ocultarte tras cajas.\n• [F] Linterna: Apágala si el alien mira hacia ti.\n• [E] Armario: Entra para volverte invisible.\n• [M] Radar: Detecta al alien (peligro <15m).\n• [I] Fabricar: Crea Minas PEM y Bombas de humo."
	guideBody.Parent = guideFrame

	-- Barra inferior de estado de movimiento
	local mode = Instance.new("TextLabel")
	mode.Name = "Mode"
	mode.AnchorPoint = Vector2.new(0, 1)
	mode.Position = UDim2.new(0, 20, 1, -20)
	mode.Size = UDim2.fromOffset(360, 22)
	mode.BackgroundTransparency = 1
	mode.Font = Enum.Font.GothamBold
	mode.TextSize = 14
	mode.TextXAlignment = Enum.TextXAlignment.Left
	mode.TextColor3 = Color3.fromRGB(200, 210, 220)
	mode.TextStrokeTransparency = 0.5
	mode.Parent = gui

	-- Pantalla de captura
	local captured = Instance.new("TextLabel")
	captured.Name = "Captured"
	captured.Size = UDim2.fromScale(1, 1)
	captured.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
	captured.BackgroundTransparency = 1
	captured.TextTransparency = 1
	captured.Font = Enum.Font.GothamBlack
	captured.TextSize = 42
	captured.TextColor3 = Color3.fromRGB(255, 220, 220)
	captured.Text = "CONEXIÓN PERDIDA — ASTRONAUTA CAPTURADO"
	captured.TextWrapped = true
	captured.ZIndex = 10
	captured.Parent = gui

	-- Oxígeno (solo visible si falta aire)
	local oxyBack = Instance.new("Frame")
	oxyBack.Name = "OxygenBack"
	oxyBack.AnchorPoint = Vector2.new(0.5, 0)
	oxyBack.Position = UDim2.new(0.5, 0, 0, 95)
	oxyBack.Size = UDim2.fromOffset(240, 10)
	oxyBack.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	oxyBack.BackgroundTransparency = 0.25
	oxyBack.BorderSizePixel = 0
	oxyBack.Visible = false
	oxyBack.Parent = gui
	local oxyFill = Instance.new("Frame")
	oxyFill.Name = "Fill"
	oxyFill.Size = UDim2.fromScale(1, 1)
	oxyFill.BackgroundColor3 = Color3.fromRGB(80, 170, 255)
	oxyFill.BorderSizePixel = 0
	oxyFill.Parent = oxyBack
	local oxyLabel = Instance.new("TextLabel")
	oxyLabel.Name = "Label"
	oxyLabel.AnchorPoint = Vector2.new(0.5, 1)
	oxyLabel.Position = UDim2.new(0.5, 0, 0, -2)
	oxyLabel.Size = UDim2.fromOffset(240, 16)
	oxyLabel.BackgroundTransparency = 1
	oxyLabel.Font = Enum.Font.GothamBold
	oxyLabel.TextSize = 13
	oxyLabel.TextColor3 = Color3.fromRGB(150, 210, 255)
	oxyLabel.TextStrokeTransparency = 0.5
	oxyLabel.Text = "O₂"
	oxyLabel.Parent = oxyBack

	-- Muerte por asfixia (viñeta cian)
	local asphyxia = Instance.new("TextLabel")
	asphyxia.Name = "Asphyxia"
	asphyxia.Size = UDim2.fromScale(1, 1)
	asphyxia.BackgroundColor3 = Color3.fromRGB(0, 60, 80)
	asphyxia.BackgroundTransparency = 1
	asphyxia.TextTransparency = 1
	asphyxia.Font = Enum.Font.GothamBlack
	asphyxia.TextSize = 38
	asphyxia.TextWrapped = true
	asphyxia.TextColor3 = Color3.fromRGB(150, 245, 255)
	asphyxia.Text = "CRÍTICO — ASFIXIA POR DESPRESURIZACIÓN"
	asphyxia.ZIndex = 10
	asphyxia.Parent = gui

	local hidden = Instance.new("TextLabel")
	hidden.Name = "Hidden"
	hidden.AnchorPoint = Vector2.new(0.5, 1)
	hidden.Position = UDim2.new(0.5, 0, 1, -60)
	hidden.Size = UDim2.fromOffset(300, 28)
	hidden.BackgroundTransparency = 1
	hidden.Font = Enum.Font.GothamBold
	hidden.TextSize = 18
	hidden.TextColor3 = Color3.fromRGB(170, 190, 210)
	hidden.TextStrokeTransparency = 0.4
	hidden.Text = "ESCONDIDO EN ARMARIO — [E] salir"
	hidden.Visible = false
	hidden.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	hud.status = status
	hud.fill = fill
	hud.percent = percent
	hud.mode = mode
	hud.captured = captured
	hud.oxyBack = oxyBack
	hud.oxyFill = oxyFill
	hud.oxyLabel = oxyLabel
	hud.hidden = hidden
	hud.asphyxia = asphyxia
	hud.sightWarning = sightWarning
end

local function updateSuspicion()
	local value = runtime:GetAttribute("MaxSuspicion") or 0
	local alpha = math.clamp(value / AlienConfig.Suspicion.Max, 0, 1)
	TweenService:Create(hud.fill, TweenInfo.new(0.15), { Size = UDim2.new(alpha, 0, 1, 0) }):Play()
	hud.fill.BackgroundColor3 = Color3.fromRGB(240, 200, 60):Lerp(Color3.fromRGB(230, 40, 40), alpha)
	hud.percent.Text = ("%d%% SOSPECHA"):format(math.floor(value + 0.5))

	-- Aviso visual si la sospecha está subiendo activamente
	if value > lastSuspicion and value > 0 then
		hud.sightWarning.Visible = true
	elseif value == 0 or value <= lastSuspicion then
		hud.sightWarning.Visible = false
	end
	lastSuspicion = value
end

local function updateStatus()
	local status = runtime:GetAttribute("StationStatus") or Types.StationStatus.Desapercibido
	local entry = STATUS_TEXT[status] or STATUS_TEXT[Types.StationStatus.Desapercibido]
	hud.status.Text = entry[1]
	hud.status.TextColor3 = entry[2]

	if status == Types.StationStatus.AlertaRoja then
		hud.sightWarning.Visible = true
		hud.sightWarning.Text = "🚨 ¡ALERTA ROJA! ¡EL ALIEN ESTÁ CAZANDO!"
	end
end

local function updateModeLabel()
	local character = player.Character
	local flashlight = character and character:GetAttribute("FlashlightOn") == true
	local modeNames = {
		[Types.MoveMode.Walk] = "Caminando (Normal)",
		[Types.MoveMode.Run] = "Corriendo (Haces Ruido)",
		[Types.MoveMode.Crouch] = "Agachado (Sigiloso)",
	}
	hud.mode.Text = ("Modo: %s  |  Linterna: %s"):format(
		modeNames[currentMode] or currentMode,
		flashlight and "ENCENDIDA (Peligro)" or "APAGADA (Seguro)"
	)
end

local function showCaptured(_alienName: string?, _duration: number?)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	TweenService:Create(hud.captured, TweenInfo.new(0.4), { BackgroundTransparency = 0.15, TextTransparency = 0 }):Play()
end

local function hideCaptured()
	hud.captured.BackgroundTransparency = 1
	hud.captured.TextTransparency = 1
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function updateOxygen()
	local character = player.Character
	if not character then
		return
	end
	local oxygen = character:GetAttribute("Oxygen") or AlienConfig.Vacuum.MaxOxygen
	local inVacuum = character:GetAttribute("InVacuum") == true
	hud.oxyBack.Visible = inVacuum or oxygen < AlienConfig.Vacuum.MaxOxygen
	local alpha = math.clamp(oxygen / AlienConfig.Vacuum.MaxOxygen, 0, 1)
	hud.oxyFill.Size = UDim2.fromScale(alpha, 1)
	hud.oxyFill.BackgroundColor3 = alpha > 0.25 and Color3.fromRGB(80, 170, 255) or Color3.fromRGB(255, 70, 60)
	hud.oxyLabel.Text = inVacuum and ("O₂ %d%%  •  ¡DESPRESURIZACIÓN!"):format(math.floor(oxygen)) or ("O₂ %d%%"):format(math.floor(oxygen))
end

local function updateHidden()
	local character = player.Character
	hud.hidden.Visible = character ~= nil and character:GetAttribute("HiddenInSpot") == true
end

local function onCharacterAdded(character: Model)
	runHeld = false
	crouched = false
	currentMode = Types.MoveMode.Walk
	hideCaptured()
	hud.asphyxia.BackgroundTransparency = 1
	hud.asphyxia.TextTransparency = 1
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			if character:GetAttribute("Suffocating") then
				TweenService:Create(hud.asphyxia, TweenInfo.new(0.8), { BackgroundTransparency = 0.1, TextTransparency = 0 }):Play()
			end
		end)
	end
	character:GetAttributeChangedSignal("FlashlightOn"):Connect(updateModeLabel)
	character:GetAttributeChangedSignal("Oxygen"):Connect(updateOxygen)
	character:GetAttributeChangedSignal("InVacuum"):Connect(updateOxygen)
	character:GetAttributeChangedSignal("HiddenInSpot"):Connect(updateHidden)
	character:GetAttributeChangedSignal("MoveMode"):Connect(function()
		local serverMode = character:GetAttribute("MoveMode")
		if serverMode == Types.MoveMode.Crouch then
			crouched = true
			refreshMode()
		elseif serverMode == Types.MoveMode.Walk and crouched then
			crouched = false
			refreshMode()
		end
		updateModeLabel()
	end)
	updateModeLabel()
	updateOxygen()
	updateHidden()
end

function AstronautController.Start()
	runtime = ReplicatedStorage:WaitForChild(Types.RuntimeFolderName)
	setMoveModeRemote = runtime:WaitForChild(Types.Remotes.SetMoveMode)
	toggleFlashlightRemote = runtime:WaitForChild(Types.Remotes.ToggleFlashlight)
	local capturedRemote: RemoteEvent = runtime:WaitForChild(Types.Remotes.PlayerCaptured)

	createHud()

	runtime:GetAttributeChangedSignal("MaxSuspicion"):Connect(updateSuspicion)
	runtime:GetAttributeChangedSignal("StationStatus"):Connect(updateStatus)
	updateSuspicion()
	updateStatus()

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(function(input)
		onInputEnded(input)
		updateModeLabel()
	end)
	UserInputService.InputBegan:Connect(function()
		updateModeLabel()
	end)

	capturedRemote.OnClientEvent:Connect(showCaptured)

	local meteorRemote = runtime:WaitForChild(Types.Remotes.MeteorEvent, 5) :: RemoteEvent?
	if meteorRemote then
		meteorRemote.OnClientEvent:Connect(function(phase: string, msg: string)
			if hud.sightWarning then
				hud.sightWarning.Visible = true
				hud.sightWarning.Text = msg
				if phase == "warning" then
					hud.sightWarning.TextColor3 = Color3.fromRGB(255, 180, 40)
				elseif phase == "blackout" then
					hud.sightWarning.TextColor3 = Color3.fromRGB(255, 60, 60)
				elseif phase == "restored" then
					hud.sightWarning.TextColor3 = Color3.fromRGB(120, 240, 140)
					task.delay(4, function()
						if hud.sightWarning.Text == msg then
							hud.sightWarning.Visible = false
						end
					end)
				end
			end
		end)
	end

	-- La linterna sigue en tiempo real el ángulo 3D de la cámara/mirada del jugador
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local camera = Workspace.CurrentCamera
		if character and camera then
			local head = character:FindFirstChild("Head")
			if head then
				local attachment = head:FindFirstChild("FlashlightAttachment") :: Attachment?
				if attachment and attachment:IsA("Attachment") then
					attachment.WorldCFrame = CFrame.lookAt(head.Position, head.Position + camera.CFrame.LookVector)
				end
			end
		end
	end)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

return AstronautController
