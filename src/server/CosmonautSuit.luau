--!nonstrict
-- Traje de cosmonauta retro (Milestone R4): tela beige acolchada, cintas rojas, casco esférico con
-- visor naranja reflectante y mochila de soporte vital con LED (verde = O₂ ok, rojo = sin presurización).
-- Funciona con R15 y R6. StarterPlayer.LoadCharacterAppearance = false (default.project.json) evita
-- que la ropa y accesorios del avatar tapen el traje.

local CosmonautSuit = {}

CosmonautSuit.FabricColor = Color3.fromRGB(205, 195, 170)
CosmonautSuit.GloveColor = Color3.fromRGB(150, 140, 120)
CosmonautSuit.TapeColor = Color3.fromRGB(170, 30, 25)
CosmonautSuit.VisorColor = Color3.fromRGB(255, 120, 0)
CosmonautSuit.PackColor = Color3.fromRGB(185, 178, 160)
CosmonautSuit.LedOk = Color3.fromRGB(60, 255, 90)
CosmonautSuit.LedAlert = Color3.fromRGB(255, 40, 30)

local function attach(parent: BasePart, name: string, props: { [string]: any }, offset: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false -- no tapa la linterna que vive en la cabeza
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent.Parent
	return p
end

local function isArm(name: string): boolean
	return string.find(name, "Arm") ~= nil
end

local function isHand(name: string): boolean
	return string.find(name, "Hand") ~= nil
end

local function isFoot(name: string): boolean
	return string.find(name, "Foot") ~= nil
end

function CosmonautSuit.Apply(character: Model)
	if character:GetAttribute("SuitApplied") then
		return
	end
	local head = character:WaitForChild("Head", 10)
	local torso = character:FindFirstChild("UpperTorso") or character:WaitForChild("Torso", 10)
	if not head or not torso then
		return
	end
	character:SetAttribute("SuitApplied", true)

	-- Fuera ropa, accesorios y cara
	for _, d in character:GetChildren() do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	for _, d in head:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end

	-- Tela del traje
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.Fabric
			if isHand(part.Name) or isFoot(part.Name) then
				part.Color = CosmonautSuit.GloveColor
			else
				part.Color = CosmonautSuit.FabricColor
			end
		end
	end
	head.Transparency = 1

	-- Cintas rojas en brazos (y piernas): una banda por segmento superior
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and (isArm(part.Name) or string.find(part.Name, "UpperLeg") or part.Name == "Left Leg" or part.Name == "Right Leg") then
			if not string.find(part.Name, "Lower") then
				attach(part :: BasePart, "SuitTape", {
					Size = Vector3.new(part.Size.X + 0.06, 0.22, part.Size.Z + 0.06),
					Color = CosmonautSuit.TapeColor,
					Material = Enum.Material.Fabric,
				}, CFrame.new(0, part.Size.Y * 0.15, 0))
			end
		end
	end

	-- Casco: carcasa beige + visor naranja que asoma por delante + cuello rojo
	local shell = attach(head, "HelmetShell", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.6,
		Color = Color3.fromRGB(225, 218, 200),
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, 0.15, 0.1))
	attach(head, "Visor", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.25,
		Color = CosmonautSuit.VisorColor,
		Material = Enum.Material.Glass,
		Reflectance = 0.4,
		Transparency = 0.05,
	}, CFrame.new(0, 0.12, -0.42))
	attach(head, "Collar", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 2.1, 2.1),
		Color = CosmonautSuit.TapeColor,
		Material = Enum.Material.Fabric,
	}, CFrame.new(0, -0.95, 0.05) * CFrame.Angles(0, 0, math.rad(90)))
	shell.Name = "HelmetShell"

	-- Mochila de soporte vital (la espalda es +Z del torso)
	local depth = torso.Size.Z
	local pack = attach(torso, "LifeSupportPack", {
		Size = Vector3.new(torso.Size.X * 0.95, torso.Size.Y * 1.1, 1.1),
		Color = CosmonautSuit.PackColor,
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, 0.1, depth / 2 + 0.55))
	attach(pack, "PackStripe", {
		Size = Vector3.new(pack.Size.X + 0.02, 0.2, pack.Size.Z + 0.02),
		Color = CosmonautSuit.TapeColor,
		Material = Enum.Material.Fabric,
	}, CFrame.new(0, pack.Size.Y * 0.3, 0))
	local led = attach(pack, "StatusLED", {
		Size = Vector3.new(0.3, 0.3, 0.1),
		Color = CosmonautSuit.LedOk,
		Material = Enum.Material.Neon,
	}, CFrame.new(-pack.Size.X * 0.3, -pack.Size.Y * 0.25, pack.Size.Z / 2 + 0.03))
	local ledLight = Instance.new("PointLight")
	ledLight.Range = 3
	ledLight.Brightness = 1.5
	ledLight.Color = CosmonautSuit.LedOk
	ledLight.Parent = led
	attach(pack, "OxygenDial", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 0.55, 0.55),
		Color = Color3.fromRGB(40, 40, 40),
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(pack.Size.X * 0.2, -pack.Size.Y * 0.25, pack.Size.Z / 2 + 0.03) * CFrame.Angles(0, math.rad(90), 0))

	local function updateLed()
		local alert = character:GetAttribute("InVacuum") == true or (character:GetAttribute("Oxygen") or 100) <= 0
		local color = alert and CosmonautSuit.LedAlert or CosmonautSuit.LedOk
		led.Color = color
		ledLight.Color = color
	end
	character:GetAttributeChangedSignal("InVacuum"):Connect(updateLed)
	character:GetAttributeChangedSignal("Oxygen"):Connect(updateLed)
	updateLed()

	-- Accesorios que lleguen tarde (si alguien reactiva la apariencia)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			task.defer(function()
				child:Destroy()
			end)
		end
	end)
end

return CosmonautSuit
