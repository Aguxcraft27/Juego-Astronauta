--!nonstrict
-- Zonas de despresurización (tag "VacuumZone"): volúmenes Part (CanCollide = false).
-- Dentro de una zona activa el oxígeno baja OxygenDrainRate/s; a 0 la salud baja SuffocationDamageRate/s.
-- Fuera se recarga OxygenRefillRate/s. Atributos en el Character: "Oxygen" (0-100), "InVacuum" (bool).
-- Una esclusa se abre/cierra al espacio con VacuumService.SetZoneActive(zone, bool) o el atributo "Active".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local AlienConfig = require(Shared:WaitForChild("AlienConfig"))

local Cfg = AlienConfig.Vacuum
local VacuumService = {}

local TICK = 0.1

local function isZoneActive(zone: BasePart): boolean
	return zone:GetAttribute("Active") ~= false
end

local function isInsideZone(zone: BasePart, position: Vector3): boolean
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

function VacuumService.IsInVacuum(position: Vector3): boolean
	for _, zone in CollectionService:GetTagged(Types.Tags.VacuumZone) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(Workspace) and isZoneActive(zone) and isInsideZone(zone, position) then
			return true
		end
	end
	return false
end

function VacuumService.SetZoneActive(zone: BasePart, active: boolean)
	zone:SetAttribute("Active", active)
end

local function updateCharacter(character: Model, dt: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local oxygen = character:GetAttribute("Oxygen") or Cfg.MaxOxygen
	local inVacuum = VacuumService.IsInVacuum(root.Position)

	if inVacuum then
		oxygen = math.max(0, oxygen - Cfg.OxygenDrainRate * dt)
		if oxygen <= 0 then
			character:SetAttribute("Suffocating", true) -- el cliente muestra la pantalla de asfixia si muere así
			humanoid:TakeDamage(Cfg.SuffocationDamageRate * dt)
		end
	else
		oxygen = math.min(Cfg.MaxOxygen, oxygen + Cfg.OxygenRefillRate * dt)
	end
	if oxygen > 0 and character:GetAttribute("Suffocating") then
		character:SetAttribute("Suffocating", nil)
	end

	-- Redondeo a décimas para no replicar ruido de coma flotante
	character:SetAttribute("Oxygen", math.floor(oxygen * 10 + 0.5) / 10)
	if character:GetAttribute("InVacuum") ~= inVacuum then
		character:SetAttribute("InVacuum", inVacuum)
	end
end

function VacuumService.Init()
	local function onCharacter(character: Model)
		character:SetAttribute("Oxygen", Cfg.MaxOxygen)
		character:SetAttribute("InVacuum", false)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(step)
		accumulator += step
		if accumulator < TICK then
			return
		end
		local dt = accumulator
		accumulator = 0
		for _, player in Players:GetPlayers() do
			if player.Character then
				updateCharacter(player.Character, dt)
			end
		end
	end)
end

return VacuumService
