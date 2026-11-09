--!nonstrict
-- Rastro de sangre (Milestone R3). Con salud < 40 el jugador deja gotas (tag "BloodDrop")
-- cada 2 s en movimiento o cada 4 s quieto. Duran 60 s (desvaneciéndose al final).
-- Atributo "SpawnTime" (os.clock del servidor) para que la IA siga la gota más reciente.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local CraftingConfig = require(Shared:WaitForChild("CraftingConfig"))

local Cfg = CraftingConfig.Blood
local BloodTrailService = {}

local lastDrop: { [Player]: number } = {}
local folder: Folder

local function getFolder(): Folder
	if not folder or folder.Parent == nil then
		folder = Instance.new("Folder")
		folder.Name = "BloodTrail"
		folder.Parent = Workspace
	end
	return folder
end

local function spawnDrop(character: Model, root: BasePart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, getFolder() }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -10, 0), params)
	if not hit then
		return
	end

	local size = 1.2 + math.random() * 1.0
	local drop = Instance.new("Part")
	drop.Name = "BloodDrop"
	drop.Shape = Enum.PartType.Cylinder
	drop.Size = Vector3.new(0.05, size, size * (0.7 + math.random() * 0.3))
	-- Cilindro tumbado: el eje X apunta hacia arriba (normal de la superficie)
	drop.CFrame = CFrame.lookAt(hit.Position, hit.Position + hit.Normal) * CFrame.Angles(0, math.rad(90), 0)
		+ hit.Normal * 0.03
	drop.Anchored = true
	drop.CanCollide = false
	drop.CanTouch = false
	drop.CanQuery = false
	drop.CastShadow = false
	drop.Material = Enum.Material.SmoothPlastic
	drop.Color = Color3.fromRGB(110 + math.random(0, 30), 0, 0)
	drop:SetAttribute("SpawnTime", os.clock())
	drop.Parent = getFolder()
	CollectionService:AddTag(drop, Types.Tags.BloodDrop)

	task.delay(Cfg.Lifetime - Cfg.FadeTime, function()
		if drop.Parent then
			TweenService:Create(drop, TweenInfo.new(Cfg.FadeTime), { Transparency = 1 }):Play()
		end
	end)
	task.delay(Cfg.Lifetime, function()
		if drop.Parent then
			drop:Destroy()
		end
	end)
end

local function update()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 and humanoid.Health < Cfg.HealthThreshold
			and not character:GetAttribute("HiddenInSpot") and not character:GetAttribute("Captured") then
			local v = root.AssemblyLinearVelocity
			local moving = Vector3.new(v.X, 0, v.Z).Magnitude >= Cfg.MinMoveSpeed
			local interval = moving and Cfg.IntervalMoving or Cfg.IntervalStill
			if now - (lastDrop[player] or 0) >= interval then
				lastDrop[player] = now
				spawnDrop(character, root)
			end
			if character:GetAttribute("Bleeding") ~= true then
				character:SetAttribute("Bleeding", true)
			end
		elseif character and character:GetAttribute("Bleeding") then
			character:SetAttribute("Bleeding", nil)
		end
	end
end

function BloodTrailService.Init()
	getFolder()
	Players.PlayerRemoving:Connect(function(player)
		lastDrop[player] = nil
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(step)
		accumulator += step
		if accumulator >= 0.2 then
			accumulator = 0
			update()
		end
	end)
end

return BloodTrailService
