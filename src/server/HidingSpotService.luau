--!nonstrict
-- Armarios / taquillas (tag "HidingSpot"). Cada uno recibe un ProximityPrompt "Esconderse".
-- Dentro: personaje anclado en el interior, linterna apagada, atributo "HiddenInSpot" = true
-- (la visión del alien ignora a los jugadores escondidos). El armario es opaco: solo el ruido delata.
--
-- Estructura del escondite (Model o Part con tag "HidingSpot"):
--   - Part "HidePoint" (opcional): dónde queda el jugador; por defecto el centro del escondite.
--   - Part "ExitPoint" (opcional): dónde sale; por defecto 4 studs delante (LookVector) del escondite.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local StationAlarmService = require(script.Parent:WaitForChild("StationAlarmService"))

local HidingSpotService = {}

local occupantBySpot: { [Instance]: Model } = {}
local spotByCharacter: { [Model]: Instance } = {}
local prompts: { [Instance]: ProximityPrompt } = {}

local enteredEvent = Instance.new("BindableEvent")
local exitedEvent = Instance.new("BindableEvent")
HidingSpotService.PlayerEntering = enteredEvent.Event -- (character, spot) se dispara ANTES de ocultarlo
HidingSpotService.PlayerExited = exitedEvent.Event -- (character, spot)

local function spotPart(spot: Instance): BasePart?
	return StationAlarmService.GetPart(spot)
end

function HidingSpotService.GetHidePosition(spot: Instance): Vector3
	local hide = spot:FindFirstChild("HidePoint", true)
	if hide and hide:IsA("BasePart") then
		return hide.Position
	end
	local part = spotPart(spot)
	return part and part.Position or Vector3.zero
end

function HidingSpotService.GetExitCFrame(spot: Instance): CFrame
	local exit = spot:FindFirstChild("ExitPoint", true)
	if exit and exit:IsA("BasePart") then
		return exit.CFrame
	end
	local part = spotPart(spot)
	if not part then
		return CFrame.new()
	end
	local look = part.CFrame.LookVector
	local pos = part.Position + Vector3.new(look.X, 0, look.Z).Unit * (part.Size.Z / 2 + 3)
	return CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z))
end

function HidingSpotService.GetOccupant(spot: Instance): Model?
	return occupantBySpot[spot]
end

function HidingSpotService.GetSpotOf(character: Model): Instance?
	return spotByCharacter[character]
end

function HidingSpotService.FindNearest(position: Vector3, maxDistance: number): Instance?
	local best, bestDist = nil, maxDistance
	for _, spot in CollectionService:GetTagged(Types.Tags.HidingSpot) do
		local part = spotPart(spot)
		if part and part:IsDescendantOf(Workspace) then
			local d = (part.Position - position).Magnitude
			if d <= bestDist then
				best, bestDist = spot, d
			end
		end
	end
	return best
end

local function setPromptText(spot: Instance, occupied: boolean)
	local prompt = prompts[spot]
	if prompt then
		prompt.ActionText = occupied and "Salir" or "Esconderse"
	end
end

function HidingSpotService.Enter(character: Model, spot: Instance): boolean
	if occupantBySpot[spot] or spotByCharacter[character] then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Captured") then
		return false
	end

	-- Los aliens deciden ANTES de que desaparezca si lo han visto meterse.
	enteredEvent:Fire(character, spot)
	if character:GetAttribute("Captured") then
		return false
	end

	occupantBySpot[spot] = character
	spotByCharacter[character] = spot
	PlayerStateService.SetFlashlight(character, false)
	character:SetAttribute("HiddenInSpot", true)

	root.Anchored = true
	local hidePos = HidingSpotService.GetHidePosition(spot)
	local exitCF = HidingSpotService.GetExitCFrame(spot)
	-- Mirando hacia la puerta del armario
	character:PivotTo(CFrame.lookAt(hidePos, hidePos + exitCF.LookVector))
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("PreHideCanQuery", d.CanQuery)
			d.CanQuery = false -- ningún raycast lo encuentra dentro
		end
	end
	setPromptText(spot, true)
	return true
end

function HidingSpotService.Exit(character: Model)
	local spot = spotByCharacter[character]
	if not spot then
		return
	end
	occupantBySpot[spot] = nil
	spotByCharacter[character] = nil
	character:SetAttribute("HiddenInSpot", nil)

	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			local prev = d:GetAttribute("PreHideCanQuery")
			if prev ~= nil then
				d.CanQuery = prev
				d:SetAttribute("PreHideCanQuery", nil)
			end
		end
	end
	if character.Parent then
		character:PivotTo(HidingSpotService.GetExitCFrame(spot) + Vector3.new(0, 3, 0))
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and not character:GetAttribute("Captured") then
			root.Anchored = false
		end
	end
	setPromptText(spot, false)
	exitedEvent:Fire(character, spot)
end

-- Un alien abre el armario a la fuerza: el ocupante queda fuera y a la vista.
function HidingSpotService.ForceOpen(spot: Instance): Model?
	local occupant = occupantBySpot[spot]
	if occupant then
		HidingSpotService.Exit(occupant)
	end
	return occupant
end

local function setupSpot(spot: Instance)
	if prompts[spot] then
		return
	end
	local part = spotPart(spot)
	if not part then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HidePrompt"
	prompt.ActionText = "Esconderse"
	prompt.ObjectText = "Armario"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompts[spot] = prompt

	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		if not character then
			return
		end
		local current = spotByCharacter[character]
		if current == spot then
			HidingSpotService.Exit(character)
		elseif current == nil then
			HidingSpotService.Enter(character, spot)
		end
	end)
end

function HidingSpotService.Init()
	for _, spot in CollectionService:GetTagged(Types.Tags.HidingSpot) do
		setupSpot(spot)
	end
	CollectionService:GetInstanceAddedSignal(Types.Tags.HidingSpot):Connect(setupSpot)

	local function release(character: Model)
		local spot = spotByCharacter[character]
		if spot then
			occupantBySpot[spot] = nil
			spotByCharacter[character] = nil
			setPromptText(spot, false)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			release(player.Character)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(release)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterRemoving:Connect(release)
	end
end

return HidingSpotService
