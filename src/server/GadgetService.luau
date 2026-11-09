--!nonstrict
-- Uso de gadgets (Milestone R3). Llamado por CraftingService tras validar el inventario.
-- Use() devuelve true si el gadget se gastó.
--   EMPMine   : se coloca en el suelo; tras ArmDelay, un alien a <= 5 studs la detona -> aturdido 5 s.
--   SmokeBomb : proyectil hacia donde mira el jugador; al impactar, nube (tag SmokeCloud) de radio 10 durante 8 s.
--               La IA trata cada SmokeCloud como esfera opaca (AlienAIService.CanSeePoint).
--   Medkit    : +50 de salud (por encima del umbral de sangrado, así que corta el rastro).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local CraftingConfig = require(Shared:WaitForChild("CraftingConfig"))
local AlienAIService = require(script.Parent:WaitForChild("AlienAIService"))

local Cfg = CraftingConfig.Gadget
local GadgetService = {}

local gadgetFolder: Folder

local function getFolder(): Folder
	if not gadgetFolder or gadgetFolder.Parent == nil then
		gadgetFolder = Instance.new("Folder")
		gadgetFolder.Name = "Gadgets"
		gadgetFolder.Parent = Workspace
	end
	return gadgetFolder
end

local function rayParamsFor(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, getFolder() }
	params.RespectCanCollide = true
	return params
end

local function playSoundAt(position: Vector3, soundId: string, volume: number)
	if soundId == "" then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = getFolder()
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 5)
end

-- Mina PEM -------------------------------------------------------------------------------
local mines: { [BasePart]: { armedAt: number } } = {}

local function detonateMine(mine: BasePart)
	mines[mine] = nil
	local pos = mine.Position
	local emp = Cfg.EMP

	-- Aturdir a todos los aliens dentro del radio de disparo
	for model, brain in AlienAIService.GetBrains() do
		if brain:IsValid() and (brain.root.Position - pos).Magnitude <= emp.TriggerRadius + 1 then
			AlienAIService.Stun(model, emp.StunDuration)
		end
	end

	-- Destello azul
	local flash = Instance.new("Part")
	flash.Name = "EMPFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Material = Enum.Material.Neon
	flash.Color = emp.LightColor
	flash.Transparency = 0.3
	flash.Size = Vector3.one * 2
	flash.Position = pos
	flash.Parent = getFolder()
	local light = Instance.new("PointLight")
	light.Color = emp.LightColor
	light.Range = 25
	light.Brightness = 8
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * emp.TriggerRadius * 2.5,
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 1)

	playSoundAt(pos, emp.SoundId, 1)
	mine:Destroy()
end

local function placeMine(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local origin = root.Position + root.CFrame.LookVector * 2
	local hit = Workspace:Raycast(origin, Vector3.new(0, -12, 0), rayParamsFor(character))
	if not hit then
		return false -- no hay suelo
	end

	local mine = Instance.new("Part")
	mine.Name = "EMPMine"
	mine.Shape = Enum.PartType.Cylinder
	mine.Size = Vector3.new(0.4, 2, 2)
	mine.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	mine.Anchored = true
	mine.CanCollide = false
	mine.CanQuery = false
	mine.Material = Enum.Material.Metal
	mine.Color = Color3.fromRGB(40, 50, 70)
	mine.Parent = getFolder()

	local led = Instance.new("PointLight")
	led.Color = Cfg.EMP.LightColor
	led.Range = 4
	led.Brightness = 1
	led.Enabled = false
	led.Parent = mine

	mine:SetAttribute("Owner", player.UserId)
	CollectionService:AddTag(mine, Types.Tags.EMPMine)
	mines[mine] = { armedAt = os.clock() + Cfg.EMP.ArmDelay }
	task.delay(Cfg.EMP.ArmDelay, function()
		if mine.Parent then
			led.Enabled = true -- armada
		end
	end)
	return true
end

local function updateMines()
	local now = os.clock()
	for mine, data in mines do
		if mine.Parent == nil then
			mines[mine] = nil
		elseif now >= data.armedAt then
			for _, brain in AlienAIService.GetBrains() do
				if brain:IsValid() then
					local offset = brain.root.Position - mine.Position
					if Vector3.new(offset.X, 0, offset.Z).Magnitude <= Cfg.EMP.TriggerRadius and math.abs(offset.Y) < 8 then
						detonateMine(mine)
						break
					end
				end
			end
		end
	end
end

-- Bomba de humo ------------------------------------------------------------------------------
local function spawnSmoke(position: Vector3)
	local smoke = Cfg.Smoke
	local cloud = Instance.new("Part")
	cloud.Name = "SmokeCloud"
	cloud.Shape = Enum.PartType.Ball
	cloud.Size = Vector3.one * smoke.Radius * 2
	cloud.Position = position
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false -- la IA usa intersección con la esfera, no raycast
	cloud.CanTouch = false
	cloud.CastShadow = false
	cloud.Material = Enum.Material.SmoothPlastic
	cloud.Color = Color3.fromRGB(150, 150, 155)
	cloud.Transparency = 0.25
	cloud:SetAttribute("Radius", smoke.Radius)
	cloud.Parent = getFolder()

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(170, 170, 175))
	emitter.Size = NumberSequence.new(6, 10)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = cloud

	CollectionService:AddTag(cloud, Types.Tags.SmokeCloud)

	-- Se disipa en el último segundo
	task.delay(smoke.Duration - 1, function()
		if cloud.Parent then
			emitter.Enabled = false
			TweenService:Create(cloud, TweenInfo.new(1), { Transparency = 1 }):Play()
		end
	end)
	task.delay(smoke.Duration, function()
		if cloud.Parent then
			cloud:Destroy()
		end
	end)
end

local function throwSmoke(player: Player): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not head or not root then
		return false
	end
	local smoke = Cfg.Smoke
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local up = math.rad(smoke.ThrowUpAngle)
	local direction = (flatLook * math.cos(up) + Vector3.new(0, math.sin(up), 0)).Unit

	local grenade = Instance.new("Part")
	grenade.Name = "SmokeBomb"
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.one * 0.8
	grenade.Color = Color3.fromRGB(90, 100, 90)
	grenade.Material = Enum.Material.Metal
	grenade.CanCollide = true
	grenade.Position = head.Position + flatLook * 2
	grenade.Parent = getFolder()
	grenade:SetNetworkOwner(nil)
	grenade.AssemblyLinearVelocity = direction * smoke.ThrowSpeed

	local exploded = false
	local function explode()
		if exploded or grenade.Parent == nil then
			return
		end
		exploded = true
		local pos = grenade.Position
		grenade:Destroy()
		spawnSmoke(pos)
	end
	grenade.Touched:Connect(function(other)
		if not other:IsDescendantOf(character) and other.CanCollide then
			explode()
		end
	end)
	task.delay(smoke.FuseMax, explode)
	return true
end

-- Botiquín ---------------------------------------------------------------------------------
local function useMedkit(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.Health >= humanoid.MaxHealth then
		return false
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Cfg.Medkit.Heal)
	return true
end

-- API ----------------------------------------------------------------------------------------
function GadgetService.Use(player: Player, gadget: string): boolean
	local character = player.Character
	if not character or character:GetAttribute("HiddenInSpot") or character:GetAttribute("Captured") then
		return false
	end
	if gadget == "EMPMine" then
		return placeMine(player)
	elseif gadget == "SmokeBomb" then
		return throwSmoke(player)
	elseif gadget == "Medkit" then
		return useMedkit(player)
	end
	return false
end

function GadgetService.Init()
	getFolder()
	RunService.Heartbeat:Connect(updateMines)
end

return GadgetService
