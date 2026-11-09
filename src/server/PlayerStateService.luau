--!nonstrict
-- Estado de sigilo del jugador, autoritativo en el servidor:
-- modo de movimiento (Walk / Run / Crouch), linterna y pasos audibles para la IA.
-- El cliente solo pide cambios por RemoteEvent; el servidor valida y aplica WalkSpeed y atributos.
-- Atributos en el Character: "MoveMode" (string), "FlashlightOn" (bool).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local AlienConfig = require(Shared:WaitForChild("AlienConfig"))
local CosmonautSuit = require(script.Parent:WaitForChild("CosmonautSuit"))

local PlayerStateService = {}

type NoiseCallback = (position: Vector3, radius: number, delta: number, source: Model) -> ()

local noiseCallback: NoiseCallback? = nil
local lastStepTime: { [Player]: number } = {}

local VALID_MODES = {
	[Types.MoveMode.Walk] = AlienConfig.Player.WalkSpeed,
	[Types.MoveMode.Run] = AlienConfig.Player.RunSpeed,
	[Types.MoveMode.Crouch] = AlienConfig.Player.CrouchSpeed,
}

local function getHumanoid(character: Model?): Humanoid?
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

function PlayerStateService.GetMoveMode(character: Model): string
	return character:GetAttribute("MoveMode") or Types.MoveMode.Walk
end

function PlayerStateService.IsFlashlightOn(character: Model): boolean
	return character:GetAttribute("FlashlightOn") == true
end

local function applyMoveMode(character: Model, mode: string)
	local speed = VALID_MODES[mode]
	local humanoid = getHumanoid(character)
	if not speed or not humanoid then
		return
	end
	character:SetAttribute("MoveMode", mode)
	humanoid.WalkSpeed = speed
end

local function getOrCreateFlashlight(character: Model): SpotLight?
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local attachment = head:FindFirstChild("FlashlightAttachment") :: Attachment?
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "FlashlightAttachment"
		attachment.Parent = head
	end
	local light = attachment:FindFirstChild("Flashlight") :: SpotLight?
	if not light then
		light = Instance.new("SpotLight")
		light.Name = "Flashlight"
		light.Face = Enum.NormalId.Front
		light.Range = 55
		light.Angle = 55
		light.Brightness = 3.5
		light.Shadows = true
		light.Enabled = false
		light.Parent = attachment
	end
	return light
end

local function setFlashlight(character: Model, on: boolean)
	if on and (character:GetAttribute("HiddenInSpot") or character:GetAttribute("Captured")) then
		on = false
	end
	local light = getOrCreateFlashlight(character)
	if light then
		light.Enabled = on
	end
	character:SetAttribute("FlashlightOn", on)
end

PlayerStateService.SetFlashlight = setFlashlight

function PlayerStateService.IsTrackerActive(character: Model): boolean
	return character:GetAttribute("TrackerOn") == true
end

local function onCharacterAdded(player: Player, character: Model)
	lastStepTime[player] = 0
	character:SetAttribute("MoveMode", Types.MoveMode.Walk)
	character:SetAttribute("FlashlightOn", false)
	character:SetAttribute("TrackerOn", false)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		applyMoveMode(character, Types.MoveMode.Walk)
	end
	character:WaitForChild("Head", 10)
	getOrCreateFlashlight(character)
	CosmonautSuit.Apply(character)
end

-- Pasos: cada Interval s, si el jugador se mueve por el suelo, emite ruido según su modo.
local function updateFootsteps()
	if not noiseCallback then
		return
	end
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = getHumanoid(character)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			local velocity = root.AssemblyLinearVelocity
			local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
			local mode = PlayerStateService.GetMoveMode(character)
			local step = AlienConfig.Footsteps[mode]
			if step and grounded and horizontalSpeed >= AlienConfig.Footsteps.MinSpeed and step.Radius > 0 then
				if now - (lastStepTime[player] or 0) >= step.Interval then
					lastStepTime[player] = now
					noiseCallback(root.Position, step.Radius, step.Delta, character)
				end
			end
		end
	end
end

function PlayerStateService.Init(runtimeFolder: Folder, onNoise: NoiseCallback)
	noiseCallback = onNoise

	local setMoveMode = Instance.new("RemoteEvent")
	setMoveMode.Name = Types.Remotes.SetMoveMode
	setMoveMode.Parent = runtimeFolder

	local toggleFlashlight = Instance.new("RemoteEvent")
	toggleFlashlight.Name = Types.Remotes.ToggleFlashlight
	toggleFlashlight.Parent = runtimeFolder

	local setTracker = Instance.new("RemoteEvent")
	setTracker.Name = Types.Remotes.SetTrackerActive
	setTracker.Parent = runtimeFolder
	setTracker.OnServerEvent:Connect(function(player: Player, active: any)
		if typeof(active) == "boolean" and player.Character then
			player.Character:SetAttribute("TrackerOn", active)
		end
	end)

	setMoveMode.OnServerEvent:Connect(function(player: Player, mode: any)
		if typeof(mode) ~= "string" or VALID_MODES[mode] == nil then
			return
		end
		if player.Character then
			applyMoveMode(player.Character, mode)
		end
	end)

	toggleFlashlight.OnServerEvent:Connect(function(player: Player)
		local character = player.Character
		if character then
			setFlashlight(character, not PlayerStateService.IsFlashlightOn(character))
		end
	end)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastStepTime[player] = nil
	end)

	RunService.Heartbeat:Connect(updateFootsteps)
end

return PlayerStateService
