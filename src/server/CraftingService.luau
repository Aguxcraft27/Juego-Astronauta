--!nonstrict
-- Inventario + crafteo en tiempo real (Milestone R3). Autoritativo en el servidor.
-- Inventario replicado como atributos del Player: "Res_<Recurso>" y "Gadget_<Id>" (number).
-- Crafteo: 2.5 s; se cancela si el jugador se aleja > 2 studs de donde empezó o recibe daño.
-- Los recursos se consumen SOLO al completar.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local CraftingConfig = require(Shared:WaitForChild("CraftingConfig"))
local GadgetService = require(script.Parent:WaitForChild("GadgetService"))

local CraftingService = {}

type CraftJob = {
	gadget: string,
	startTime: number,
	startPos: Vector3,
	healthConn: RBXScriptConnection?,
}

local jobs: { [Player]: CraftJob } = {}
local craftStateRemote: RemoteEvent

-- Inventario ------------------------------------------------------------------------
local function resKey(resource: string): string
	return "Res_" .. resource
end

local function gadgetKey(gadget: string): string
	return "Gadget_" .. gadget
end

function CraftingService.GetResource(player: Player, resource: string): number
	return player:GetAttribute(resKey(resource)) or 0
end

function CraftingService.AddResource(player: Player, resource: string, amount: number)
	if table.find(CraftingConfig.Resources, resource) == nil then
		warn("[CRAFTEO] Recurso desconocido: " .. tostring(resource))
		return
	end
	player:SetAttribute(resKey(resource), math.max(0, CraftingService.GetResource(player, resource) + amount))
end

function CraftingService.GetGadgetCount(player: Player, gadget: string): number
	return player:GetAttribute(gadgetKey(gadget)) or 0
end

function CraftingService.AddGadget(player: Player, gadget: string, amount: number): boolean
	local current = CraftingService.GetGadgetCount(player, gadget)
	if amount > 0 and current + amount > CraftingConfig.Craft.MaxStack then
		return false
	end
	player:SetAttribute(gadgetKey(gadget), math.max(0, current + amount))
	return true
end

function CraftingService.CanCraft(player: Player, gadget: string): boolean
	local recipe = CraftingConfig.Recipes[gadget]
	if not recipe or CraftingService.GetGadgetCount(player, gadget) >= CraftingConfig.Craft.MaxStack then
		return false
	end
	for resource, amount in recipe do
		if CraftingService.GetResource(player, resource) < amount then
			return false
		end
	end
	return true
end

local function initInventory(player: Player)
	for _, r in CraftingConfig.Resources do
		player:SetAttribute(resKey(r), 0)
	end
	for _, g in CraftingConfig.Gadgets do
		player:SetAttribute(gadgetKey(g), 0)
	end
end

-- Crafteo --------------------------------------------------------------------------------
local function endJob(player: Player)
	local job = jobs[player]
	if job then
		if job.healthConn then
			job.healthConn:Disconnect()
		end
		jobs[player] = nil
		player:SetAttribute("Crafting", nil)
	end
	return job
end

function CraftingService.Cancel(player: Player, reason: string)
	local job = endJob(player)
	if job then
		craftStateRemote:FireClient(player, "cancelled", job.gadget, reason)
	end
end

local function startCraft(player: Player, gadget: any)
	if typeof(gadget) ~= "string" or CraftingConfig.Recipes[gadget] == nil or jobs[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if character:GetAttribute("HiddenInSpot") or character:GetAttribute("Captured") then
		return
	end
	if not CraftingService.CanCraft(player, gadget) then
		craftStateRemote:FireClient(player, "cancelled", gadget, "Sin materiales")
		return
	end

	local job: CraftJob = {
		gadget = gadget,
		startTime = os.clock(),
		startPos = root.Position,
		healthConn = nil,
	}
	local lastHealth = humanoid.Health
	job.healthConn = humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			CraftingService.Cancel(player, "Daño recibido")
		end
		lastHealth = health
	end)
	jobs[player] = job
	player:SetAttribute("Crafting", gadget)
	craftStateRemote:FireClient(player, "started", gadget, CraftingConfig.Craft.Duration)
end

local function completeCraft(player: Player, job: CraftJob)
	endJob(player)
	-- Revalidar: el inventario pudo cambiar durante los 2.5 s
	if not CraftingService.CanCraft(player, job.gadget) then
		craftStateRemote:FireClient(player, "cancelled", job.gadget, "Sin materiales")
		return
	end
	for resource, amount in CraftingConfig.Recipes[job.gadget] do
		CraftingService.AddResource(player, resource, -amount)
	end
	CraftingService.AddGadget(player, job.gadget, 1)
	craftStateRemote:FireClient(player, "completed", job.gadget)
end

local function updateJobs()
	local now = os.clock()
	for player, job in jobs do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 or character:GetAttribute("Captured") then
			CraftingService.Cancel(player, "Interrumpido")
		else
			local offset = root.Position - job.startPos
			if Vector3.new(offset.X, 0, offset.Z).Magnitude > CraftingConfig.Craft.MaxMoveDistance then
				CraftingService.Cancel(player, "Te has movido")
			elseif now - job.startTime >= CraftingConfig.Craft.Duration then
				completeCraft(player, job)
			end
		end
	end
end

-- Recogida de recursos ----------------------------------------------------------------------
local function setupPickup(inst: Instance)
	if not inst:IsA("BasePart") or inst:FindFirstChild("PickupPrompt") then
		return
	end
	local resource = inst:GetAttribute("Resource")
	if typeof(resource) ~= "string" or table.find(CraftingConfig.Resources, resource) == nil then
		warn(("[CRAFTEO] %s: atributo Resource inválido (%s)"):format(inst:GetFullName(), tostring(resource)))
		return
	end
	local amount = inst:GetAttribute("Amount") or CraftingConfig.Pickup.DefaultAmount

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Recoger"
	prompt.ObjectText = ("%s x%d"):format(CraftingConfig.ResourceNames[resource] or resource, amount)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.HoldDuration = 0.3
	prompt.Parent = inst

	local taken = false
	prompt.Triggered:Connect(function(player: Player)
		if taken then
			return
		end
		taken = true
		CraftingService.AddResource(player, resource, amount)
		inst:Destroy()
	end)
end

-- Init ------------------------------------------------------------------------------------------
function CraftingService.Init(runtimeFolder: Folder)
	local requestCraft = Instance.new("RemoteEvent")
	requestCraft.Name = Types.Remotes.RequestCraft
	requestCraft.Parent = runtimeFolder

	local cancelCraft = Instance.new("RemoteEvent")
	cancelCraft.Name = Types.Remotes.CancelCraft
	cancelCraft.Parent = runtimeFolder

	local useGadget = Instance.new("RemoteEvent")
	useGadget.Name = Types.Remotes.UseGadget
	useGadget.Parent = runtimeFolder

	craftStateRemote = Instance.new("RemoteEvent")
	craftStateRemote.Name = Types.Remotes.CraftState
	craftStateRemote.Parent = runtimeFolder

	requestCraft.OnServerEvent:Connect(startCraft)
	cancelCraft.OnServerEvent:Connect(function(player)
		CraftingService.Cancel(player, "Cancelado")
	end)

	useGadget.OnServerEvent:Connect(function(player: Player, gadget: any)
		if typeof(gadget) ~= "string" or CraftingService.GetGadgetCount(player, gadget) <= 0 then
			return
		end
		if jobs[player] then
			return -- no se usan gadgets mientras se fabrica
		end
		if GadgetService.Use(player, gadget) then
			CraftingService.AddGadget(player, gadget, -1)
		end
	end)

	Players.PlayerAdded:Connect(initInventory)
	for _, player in Players:GetPlayers() do
		initInventory(player)
	end
	Players.PlayerRemoving:Connect(endJob)

	for _, inst in CollectionService:GetTagged(Types.Tags.ResourcePickup) do
		setupPickup(inst)
	end
	CollectionService:GetInstanceAddedSignal(Types.Tags.ResourcePickup):Connect(setupPickup)

	RunService.Heartbeat:Connect(updateJobs)
end

return CraftingService
