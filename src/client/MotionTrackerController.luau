--!nonstrict
-- Rastreador de movimiento (tecla M). Radar semicircular (180° hacia donde mira la cámara, 45 studs).
-- Los blips verdes son aliens en movimiento. El pitido acelera al acercarse; el servidor decide
-- si el pitido es audible para la IA (AlienAIService.updateTrackerDanger), aquí solo hay feedback.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local AlienConfig = require(Shared:WaitForChild("AlienConfig"))

local Cfg = AlienConfig.MotionTracker
local MotionTrackerController = {}

-- Pon aquí un rbxassetid de "beep" corto (licencia libre). Vacío = solo pulso visual.
MotionTrackerController.PingSoundId = ""

local player = Players.LocalPlayer
local RADAR_SIZE = 220 -- px (ancho); alto = mitad + margen
local MAX_BLIPS = 8

local active = false
local setTrackerRemote: RemoteEvent
local gui: ScreenGui
local radar: Frame
local sweep: Frame
local blips: { Frame } = {}
local distanceLabel: TextLabel
local pingSound: Sound?
type Sample = { pos: Vector3, t: number, speed: number }
local samples: { [BasePart]: Sample } = {}
local SAMPLE_WINDOW = 0.25
local lastPingTime = 0

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "MotionTrackerHUD"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	radar = Instance.new("Frame")
	radar.Name = "Radar"
	radar.AnchorPoint = Vector2.new(1, 1)
	radar.Position = UDim2.new(1, -24, 1, -24)
	radar.Size = UDim2.fromOffset(RADAR_SIZE, RADAR_SIZE / 2 + 24)
	radar.BackgroundColor3 = Color3.fromRGB(5, 25, 12)
	radar.BackgroundTransparency = 0.2
	radar.BorderSizePixel = 0
	radar.ClipsDescendants = true
	radar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = radar
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 200, 110)
	stroke.Thickness = 1.5
	stroke.Parent = radar

	-- Arcos de distancia (15 / 30 / 45 studs) como anillos recortados por el marco
	for i = 1, 3 do
		local r = (RADAR_SIZE / 2 - 8) * i / 3
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.new(0.5, 0, 1, -12)
		ring.Size = UDim2.fromOffset(r * 2, r * 2)
		ring.BackgroundTransparency = 1
		ring.Parent = radar
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(1, 0)
		rc.Parent = ring
		local rs = Instance.new("UIStroke")
		rs.Color = i == 1 and Color3.fromRGB(200, 80, 60) or Color3.fromRGB(40, 140, 80)
		rs.Transparency = 0.4
		rs.Parent = ring
	end

	-- Pulso de barrido
	sweep = Instance.new("Frame")
	sweep.AnchorPoint = Vector2.new(0.5, 0.5)
	sweep.Position = UDim2.new(0.5, 0, 1, -12)
	sweep.Size = UDim2.fromOffset(0, 0)
	sweep.BackgroundTransparency = 1
	sweep.Parent = radar
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(1, 0)
	sc.Parent = sweep
	local ss = Instance.new("UIStroke")
	ss.Name = "Stroke"
	ss.Color = Color3.fromRGB(120, 255, 160)
	ss.Thickness = 2
	ss.Parent = sweep

	-- Jugador
	local me = Instance.new("Frame")
	me.AnchorPoint = Vector2.new(0.5, 0.5)
	me.Position = UDim2.new(0.5, 0, 1, -12)
	me.Size = UDim2.fromOffset(8, 8)
	me.BackgroundColor3 = Color3.fromRGB(220, 255, 230)
	me.BorderSizePixel = 0
	me.Parent = radar
	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(1, 0)
	mc.Parent = me

	for i = 1, MAX_BLIPS do
		local blip = Instance.new("Frame")
		blip.Name = "Blip" .. i
		blip.AnchorPoint = Vector2.new(0.5, 0.5)
		blip.Size = UDim2.fromOffset(10, 10)
		blip.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
		blip.BorderSizePixel = 0
		blip.Visible = false
		blip.ZIndex = 3
		blip.Parent = radar
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = blip
		blips[i] = blip
	end

	distanceLabel = Instance.new("TextLabel")
	distanceLabel.AnchorPoint = Vector2.new(0, 0)
	distanceLabel.Position = UDim2.fromOffset(8, 4)
	distanceLabel.Size = UDim2.fromOffset(RADAR_SIZE - 16, 16)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Font = Enum.Font.Code
	distanceLabel.TextSize = 13
	distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
	distanceLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
	distanceLabel.Text = "RASTREADOR"
	distanceLabel.Parent = radar

	gui.Parent = player:WaitForChild("PlayerGui")

	if MotionTrackerController.PingSoundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = MotionTrackerController.PingSoundId
		sound.Volume = 0.5
		sound.Parent = SoundService
		pingSound = sound
	end
end

local function setActive(value: boolean)
	active = value
	gui.Enabled = value
	setTrackerRemote:FireServer(value)
	if not value then
		for _, b in blips do
			b.Visible = false
		end
	end
end

local function playPing(danger: boolean)
	if pingSound then
		pingSound.PlaybackSpeed = danger and 1.4 or 1
		pingSound:Play()
	end
	sweep.Size = UDim2.fromOffset(0, 0)
	local stroke = sweep:FindFirstChild("Stroke")
	if stroke then
		stroke.Color = danger and Color3.fromRGB(255, 90, 70) or Color3.fromRGB(120, 255, 160)
	end
	sweep:TweenSize(UDim2.fromOffset(RADAR_SIZE - 16, RADAR_SIZE - 16), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, 0.5, true)
end

local function update(dt: number)
	if not active then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not root or not camera then
		return
	end

	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(0, 0, -1)
	end
	forward = forward.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X) -- derecha en el plano XZ
	local radius = RADAR_SIZE / 2 - 8

	local shown = 0
	local nearest = math.huge
	local seen: { [BasePart]: boolean } = {}

	for _, alien in CollectionService:GetTagged(Types.Tags.Alien) do
		local aroot = alien:IsA("Model") and alien:FindFirstChild("HumanoidRootPart")
		if aroot and aroot:IsA("BasePart") then
			seen[aroot] = true
			-- Velocidad estimada por diferencia de posición en ventanas de 0.25 s
			local pos = aroot.Position
			local now = os.clock()
			local sample = samples[aroot]
			if not sample then
				sample = { pos = pos, t = now, speed = 0 }
				samples[aroot] = sample
			elseif now - sample.t >= SAMPLE_WINDOW then
				sample.speed = Vector3.new(pos.X - sample.pos.X, 0, pos.Z - sample.pos.Z).Magnitude / (now - sample.t)
				sample.pos = pos
				sample.t = now
			end
			local speed = sample.speed

			local offset = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
			local distance = offset.Magnitude
			local ahead = offset:Dot(forward)
			if speed >= Cfg.MinTargetSpeed and distance <= Cfg.Range and ahead >= 0 and shown < MAX_BLIPS then
				shown += 1
				nearest = math.min(nearest, distance)
				local side = offset:Dot(right)
				local blip = blips[shown]
				blip.Visible = true
				blip.Position = UDim2.new(0.5, side / Cfg.Range * radius, 1, -12 - ahead / Cfg.Range * radius)
				blip.BackgroundColor3 = distance <= Cfg.DangerDistance and Color3.fromRGB(255, 90, 70)
					or Color3.fromRGB(80, 255, 120)
			end
		end
	end
	for i = shown + 1, MAX_BLIPS do
		blips[i].Visible = false
	end
	for part in samples do
		if not seen[part] then
			samples[part] = nil
		end
	end

	if nearest <= Cfg.Range then
		distanceLabel.Text = ("RASTREADOR  %2d m"):format(math.floor(nearest + 0.5))
		local alpha = math.clamp(nearest / Cfg.Range, 0, 1)
		local interval = Cfg.PingIntervalNear + (Cfg.PingIntervalFar - Cfg.PingIntervalNear) * alpha
		local now = os.clock()
		if now - lastPingTime >= interval then
			lastPingTime = now
			playPing(nearest <= Cfg.DangerDistance)
		end
	else
		distanceLabel.Text = "RASTREADOR  --"
	end
end

function MotionTrackerController.Start()
	local runtime = ReplicatedStorage:WaitForChild(Types.RuntimeFolderName)
	setTrackerRemote = runtime:WaitForChild(Types.Remotes.SetTrackerActive)
	buildGui()

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			setActive(not active)
		end
	end)

	-- Al reaparecer el servidor resetea TrackerOn a false
	player.CharacterAdded:Connect(function()
		if active then
			setActive(false)
		end
	end)

	RunService.RenderStepped:Connect(update)
end

return MotionTrackerController
