--!nonstrict
-- Misión jugable (Milestone R5): tarjeta -> consola de seguridad -> esclusa de escape -> victoria.
--   Keycard (tag)         : ProximityPrompt; da Player.HasKeycard = true (persiste tras una captura).
--   SecurityConsole (tag) : requiere tarjeta; desactiva la alarma y abre las EscapeDoor.
--   EscapeDoor (tag)      : Part sólida hasta desbloquearse.
--   EscapeZone (tag)      : volumen; entrar con la esclusa abierta = victoria.
-- Mensajes al cliente: MissionEvent(eventName, text) y PlayerEscaped() para la pantalla de victoria.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local StationAlarmService = require(script.Parent:WaitForChild("StationAlarmService"))

local MissionService = {}

MissionService.Text = {
	Start = "Encuentra la TARJETA DE SEGURIDAD (mesa del módulo habitacional, Sala A)",
	Keycard = "TARJETA DE SEGURIDAD OBTENIDA — Úsala en la consola de seguridad (Sala B, pared este)",
	Denied = "ACCESO DENEGADO — Necesitas la tarjeta de seguridad",
	Unlocked = "¡ESCLUSA DE ESCAPE DESBLOQUEADA! ¡CORRE A LA SALIDA! (pasillo sur, extremo este)",
	Escaped = "¡MISIÓN CUMPLIDA — HAS ESCAPADO CON VIDA!",
}

local runtimeFolder: Folder
local missionRemote: RemoteEvent
local escapedRemote: RemoteEvent
local escapeOpen = false

local function send(player: Player?, event: string, text: string)
	if player then
		missionRemote:FireClient(player, event, text)
	else
		missionRemote:FireAllClients(event, text)
	end
end

local function makePrompt(part: BasePart, action: string, object: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MissionPrompt"
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function setupKeycard(inst: Instance)
	local part = StationAlarmService.GetPart(inst)
	if not part or part:FindFirstChild("MissionPrompt") then
		return
	end
	local prompt = makePrompt(part, "Recoger Tarjeta de Seguridad", "Tarjeta", 0.3)
	prompt.Triggered:Connect(function(player: Player)
		if player:GetAttribute("HasKeycard") then
			return
		end
		player:SetAttribute("HasKeycard", true)
		send(player, "keycard", MissionService.Text.Keycard)
		inst:Destroy()
	end)
end

local function openEscape()
	if escapeOpen then
		return
	end
	escapeOpen = true
	runtimeFolder:SetAttribute("EscapeOpen", true)
	for _, door in CollectionService:GetTagged(Types.Tags.EscapeDoor) do
		local part = StationAlarmService.GetPart(door)
		if part then
			part.CanCollide = false
			part.Transparency = 0.85
			part.Color = Color3.fromRGB(60, 220, 110)
		end
	end
	print("[MISIÓN] Esclusa de escape desbloqueada")
end

local function setupConsole(inst: Instance)
	local part = StationAlarmService.GetPart(inst)
	if not part or part:FindFirstChild("MissionPrompt") then
		return
	end
	local prompt = makePrompt(part, "Usar consola de seguridad", "Seguridad", 1.5)
	prompt.Triggered:Connect(function(player: Player)
		if escapeOpen then
			return
		end
		if not player:GetAttribute("HasKeycard") then
			send(player, "denied", MissionService.Text.Denied)
			return
		end
		StationAlarmService.DeactivateAlarm()
		openEscape()
		prompt.Enabled = false
		send(nil, "unlocked", MissionService.Text.Unlocked)
	end)
end

local function isInside(zone: BasePart, position: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(position)
	local h = zone.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function checkEscape()
	if not escapeOpen then
		return
	end
	local zones = CollectionService:GetTagged(Types.Tags.EscapeZone)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not character:GetAttribute("Escaped")
			and not character:GetAttribute("Captured") then
			for _, zone in zones do
				if zone:IsA("BasePart") and isInside(zone, root.Position) then
					character:SetAttribute("Escaped", true) -- la IA deja de percibirlo
					root.Anchored = true
					print(("[MISIÓN] %s ha escapado"):format(player.Name))
					send(player, "escaped", MissionService.Text.Escaped)
					escapedRemote:FireClient(player)
					break
				end
			end
		end
	end
end

function MissionService.Init(folder: Folder)
	runtimeFolder = folder
	runtimeFolder:SetAttribute("EscapeOpen", false)

	missionRemote = Instance.new("RemoteEvent")
	missionRemote.Name = Types.Remotes.MissionEvent
	missionRemote.Parent = folder

	escapedRemote = Instance.new("RemoteEvent")
	escapedRemote.Name = Types.Remotes.PlayerEscaped
	escapedRemote.Parent = folder

	for _, inst in CollectionService:GetTagged(Types.Tags.Keycard) do
		setupKeycard(inst)
	end
	CollectionService:GetInstanceAddedSignal(Types.Tags.Keycard):Connect(setupKeycard)
	for _, inst in CollectionService:GetTagged(Types.Tags.SecurityConsole) do
		setupConsole(inst)
	end
	CollectionService:GetInstanceAddedSignal(Types.Tags.SecurityConsole):Connect(setupConsole)

	local function onPlayer(player: Player)
		player:SetAttribute("HasKeycard", false)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			if not escapeOpen then
				send(player, "objective", player:GetAttribute("HasKeycard") and MissionService.Text.Keycard
					or MissionService.Text.Start)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(step)
		accumulator += step
		if accumulator >= 0.2 then
			accumulator = 0
			checkEscape()
		end
	end)
end

return MissionService
