--!nonstrict
-- Nivel gris de pruebas. Solo se construye si el place no tiene ya un alien con tag "Alien",
-- así que en cuanto el diseñador monte el nivel real, este módulo deja de actuar.
--
-- Planta (vista cenital, 1 carácter ≈ 10 studs):
--   +----------------+----------------+
--   |  Sala A        |  Sala B        |
--   |  [Spawn]       D  (patrulla)    |   D = puerta de seguridad (StationDoor)
--   |                |       [Alarma] |
--   +-------  -------+-------  -------+
--   |  Pasillo sur (patrulla)          |
--   +----------------------------------+

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Astronauta"):WaitForChild("Types"))
local StationDecor = require(script.Parent:WaitForChild("StationDecor"))

local TestStationBuilder = {}

local WALL_HEIGHT = 14
local FLOOR_Y = 0

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Material = Enum.Material.Metal
	p.Color = Color3.fromRGB(120, 125, 135)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function wall(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local center = Vector3.new((x1 + x2) / 2, FLOOR_Y + WALL_HEIGHT / 2, (z1 + z2) / 2)
	local size = Vector3.new(math.max(math.abs(x2 - x1), 1), WALL_HEIGHT, math.max(math.abs(z2 - z1), 1))
	part(parent, "Wall", size, center, { Color = Color3.fromRGB(90, 95, 105) })
end

local function marker(parent: Instance, name: string, position: Vector3, tag: string, order: number?)
	local p = part(parent, name, Vector3.new(1, 1, 1), position, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	if order then
		p:SetAttribute("Order", order)
	end
	CollectionService:AddTag(p, tag)
	return p
end

local function buildAlien(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Alien"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2.5, 5, 1.5)
	root.Color = Color3.fromRGB(20, 20, 25)
	root.Material = Enum.Material.SmoothPlastic
	root.CFrame = CFrame.new(position)
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.6, 1.6, 2.6) -- cráneo alargado hacia delante
	head.Color = Color3.fromRGB(30, 30, 35)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.CFrame = root.CFrame * CFrame.new(0, 3.2, -0.4)
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	-- "Ojos" para saber hacia dónde mira en las pruebas
	local eyes = Instance.new("Part")
	eyes.Name = "Eyes"
	eyes.Size = Vector3.new(1.2, 0.3, 0.2)
	eyes.Material = Enum.Material.Neon
	eyes.Color = Color3.fromRGB(255, 200, 60)
	eyes.CanCollide = false
	eyes.CanQuery = false
	eyes.Massless = true
	eyes.CFrame = head.CFrame * CFrame.new(0, 0.2, -1.3)
	eyes.Parent = model
	local eyeWeld = Instance.new("WeldConstraint")
	eyeWeld.Part0 = head
	eyeWeld.Part1 = eyes
	eyeWeld.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 0.5
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = parent
	CollectionService:AddTag(model, Types.Tags.Alien)
	return model
end

function TestStationBuilder.BuildIfEmpty(): boolean
	if #CollectionService:GetTagged(Types.Tags.Alien) > 0 or Workspace:FindFirstChild("TestStation") then
		return false
	end

	local station = Instance.new("Folder")
	station.Name = "TestStation"
	station.Parent = Workspace

	-- Suelo y techo
	part(station, "Floor", Vector3.new(200, 1, 140), Vector3.new(0, FLOOR_Y - 0.5, 0), { Color = Color3.fromRGB(70, 72, 80) })
	part(station, "Ceiling", Vector3.new(200, 1, 140), Vector3.new(0, FLOOR_Y + WALL_HEIGHT + 0.5, 0), {
		Color = Color3.fromRGB(40, 42, 48),
	})

	-- Perímetro (x: -100..100, z: -70..70)
	wall(station, -100, -70, 100, -70)
	wall(station, -100, 70, 100, 70)
	wall(station, -100, -70, -100, 70)
	wall(station, 100, -70, 100, 70)

	-- Muro que separa salas del pasillo sur (z = 20) con dos huecos
	wall(station, -100, 20, -60, 20)
	wall(station, -48, 20, 40, 20)
	wall(station, 52, 20, 100, 20)

	-- Muro entre Sala A y Sala B (x = 0) con hueco para la puerta
	wall(station, 0, -70, 0, -26)
	wall(station, 0, -14, 0, 20)

	-- Cobertura (cajas) en las salas
	part(station, "Crate", Vector3.new(8, 6, 8), Vector3.new(-40, 3, -30), { Color = Color3.fromRGB(110, 90, 60) })
	part(station, "Crate", Vector3.new(8, 6, 8), Vector3.new(40, 3, -45), { Color = Color3.fromRGB(110, 90, 60) })
	part(station, "Crate", Vector3.new(12, 6, 6), Vector3.new(20, 3, 45), { Color = Color3.fromRGB(110, 90, 60) })
	part(station, "Crate", Vector3.new(6, 6, 12), Vector3.new(-50, 3, 45), { Color = Color3.fromRGB(110, 90, 60) })

	-- Puerta de seguridad en el hueco x=0, z=-26..-14
	local door = part(station, "SecurityDoor", Vector3.new(1, WALL_HEIGHT, 12), Vector3.new(0, WALL_HEIGHT / 2, -20), {
		Color = Color3.fromRGB(60, 140, 160),
		Transparency = 0.6,
		CanCollide = false,
	})
	CollectionService:AddTag(door, Types.Tags.StationDoor)

	-- Spawn del jugador en Sala A
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(-80, FLOOR_Y + 0.5, -55)
	spawn.Transparency = 0.5
	spawn.Duration = 0
	spawn.Parent = station

	-- Ruta de patrulla: Sala B -> pasillo sur -> hueco oeste -> Sala A -> puerta -> Sala B
	marker(station, "Patrol1", Vector3.new(60, 1, -40), Types.Tags.PatrolPoint, 1)
	marker(station, "Patrol2", Vector3.new(46, 1, 45), Types.Tags.PatrolPoint, 2)
	marker(station, "Patrol3", Vector3.new(-54, 1, 45), Types.Tags.PatrolPoint, 3)
	marker(station, "Patrol4", Vector3.new(-30, 1, -10), Types.Tags.PatrolPoint, 4)
	marker(station, "Patrol5", Vector3.new(15, 1, -20), Types.Tags.PatrolPoint, 5)

	-- Consola de alarma en Sala B: escritorio metálico + monitor CRT de fósforo verde (R4)
	local deskCf = CFrame.new(85, 0, -66) * CFrame.Angles(0, math.rad(180), 0) -- mirando hacia +Z (la sala)
	part(station, "ConsoleDesk", Vector3.new(8, 3, 3.5), (deskCf * CFrame.new(0, 1.5, 0)).Position, {
		Color = Color3.fromRGB(95, 100, 98),
	})
	local _, consoleCase = StationDecor.CRT(station, deskCf * CFrame.new(-1.5, 3, 0), StationDecor.Colors.PhosphorGreen, {
		"СИСТЕМА ТРЕВОГИ",
		"ALARMA GENERAL",
		"> ESTADO: NOMINAL",
		"> _",
	})
	consoleCase.Name = "AlarmConsole"
	CollectionService:AddTag(consoleCase, Types.Tags.AlarmConsole)
	-- Botón rojo de alarma junto al monitor
	part(station, "AlarmButton", Vector3.new(1.2, 0.5, 1.2), (deskCf * CFrame.new(2.4, 3.25, 0)).Position, {
		Color = Color3.fromRGB(220, 30, 25),
		Material = Enum.Material.Neon,
	})

	-- Balizas de emergencia (apagadas hasta la Alerta Roja)
	for i, pos in { Vector3.new(-50, 12, -69), Vector3.new(50, 12, -69), Vector3.new(-50, 12, 69), Vector3.new(50, 12, 69) } do
		local beacon = part(station, "AlarmLight" .. i, Vector3.new(2, 1, 1), pos, {
			Color = Color3.fromRGB(80, 20, 20),
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 3
		light.Enabled = false
		light.Parent = beacon
		CollectionService:AddTag(beacon, Types.Tags.AlarmLight)
	end

	-- R4: focos cálidos aislados con sombras duras (islas de luz en la oscuridad)
	for _, pos in {
		Vector3.new(-75, 11, -45),
		Vector3.new(-45, 11, -45),
		Vector3.new(-30, 11, -15),
		Vector3.new(-65, 11, -15),
		Vector3.new(30, 11, -35),
		Vector3.new(60, 11, -35),
		Vector3.new(80, 11, -55),
		Vector3.new(35, 11, -10),
		Vector3.new(75, 11, -10),
		Vector3.new(-60, 11, 45),
		Vector3.new(-20, 11, 45),
		Vector3.new(20, 11, 45),
		Vector3.new(60, 11, 45),
	} do
		local lamp = StationDecor.HangingLamp(station, pos)
		CollectionService:AddTag(lamp, Types.Tags.StationLamp)
	end

	-- R4: módulo habitacional contra la pared norte de la Sala A
	StationDecor.BuildRestArea(station, CFrame.new(-62, 0, -69))

	-- R5: MISIÓN ------------------------------------------------------------------------------
	-- Tarjeta de seguridad sobre la mesa de fórmica del módulo habitacional (Sala A)
	local keycard = part(station, "Keycard", Vector3.new(1.1, 0.06, 0.7), Vector3.new(-49.2, 3.2, -62.0), {
		Color = Color3.fromRGB(230, 60, 40),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	keycard.CFrame = keycard.CFrame * CFrame.Angles(0, math.rad(25), 0)
	local cardStripe = part(station, "KeycardStripe", Vector3.new(1.12, 0.07, 0.15), keycard.Position, {
		Color = Color3.fromRGB(20, 20, 20),
		CanCollide = false,
	})
	cardStripe.CFrame = keycard.CFrame * CFrame.new(0, 0.005, -0.18)
	local cardGlow = Instance.new("PointLight")
	cardGlow.Color = Color3.fromRGB(255, 80, 60)
	cardGlow.Range = 4
	cardGlow.Brightness = 1.2
	cardGlow.Parent = keycard
	CollectionService:AddTag(keycard, Types.Tags.Keycard)
	cardStripe.Parent = keycard -- se destruye junto con la tarjeta

	-- Consola CRT de seguridad (Sala B, pared este), mirando hacia el oeste
	local secCf = CFrame.new(97, 0, -22) * CFrame.Angles(0, math.rad(90), 0)
	part(station, "SecurityDesk", Vector3.new(7, 3, 3.5), (secCf * CFrame.new(0, 1.5, 0)).Position, {
		Color = Color3.fromRGB(80, 85, 95),
	}).CFrame = secCf * CFrame.new(0, 1.5, 0)
	local _, secCase = StationDecor.CRT(station, secCf * CFrame.new(-1, 3, 0), StationDecor.Colors.PhosphorGreen, {
		"СЛУЖБА БЕЗОПАСНОСТИ",
		"SEGURIDAD",
		"> INSERTE TARJETA",
		"> ESCLUSA: BLOQUEADA",
	})
	secCase.Name = "SecurityConsole"
	CollectionService:AddTag(secCase, Types.Tags.SecurityConsole)
	local cardSlot = part(station, "CardReader", Vector3.new(1, 1.4, 0.4), (secCf * CFrame.new(2.2, 3.7, -0.6)).Position, {
		Color = Color3.fromRGB(30, 30, 30),
	})
	cardSlot.CFrame = secCf * CFrame.new(2.2, 3.7, -0.6)
	part(station, "CardReaderLED", Vector3.new(0.2, 0.2, 0.1), (secCf * CFrame.new(2.2, 4.2, -0.82)).Position, {
		Color = Color3.fromRGB(255, 40, 30),
		Material = Enum.Material.Neon,
	})

	-- Esclusa de escape: compuerta que corta el pasillo sur en x = 86; detrás, la zona de salida
	local escapeDoor = part(station, "EscapeDoor", Vector3.new(1, WALL_HEIGHT, 49), Vector3.new(86, WALL_HEIGHT / 2, 45), {
		Color = Color3.fromRGB(120, 30, 25),
		Material = Enum.Material.DiamondPlate,
	})
	CollectionService:AddTag(escapeDoor, Types.Tags.EscapeDoor)
	local escapeZone = part(station, "EscapeZone", Vector3.new(12, WALL_HEIGHT, 48), Vector3.new(93.5, WALL_HEIGHT / 2, 45), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	CollectionService:AddTag(escapeZone, Types.Tags.EscapeZone)
	-- Señal de salida verde sobre la compuerta
	local exitSign = part(station, "ExitSign", Vector3.new(0.3, 1.2, 4), Vector3.new(85.3, 12, 45), {
		Color = Color3.fromRGB(60, 255, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local exitGui = Instance.new("SurfaceGui")
	exitGui.Face = Enum.NormalId.Left
	exitGui.LightInfluence = 0
	exitGui.Parent = exitSign
	local exitText = Instance.new("TextLabel")
	exitText.Size = UDim2.fromScale(1, 1)
	exitText.BackgroundTransparency = 1
	exitText.Font = Enum.Font.GothamBlack
	exitText.TextScaled = true
	exitText.TextColor3 = Color3.fromRGB(10, 40, 20)
	exitText.Text = "ВЫХОД · SALIDA"
	exitText.Parent = exitGui

	-- R4: terminal CRT ámbar suelto en el pasillo sur (ambientación)
	part(station, "TerminalStand", Vector3.new(3.5, 3, 3), Vector3.new(0, 1.5, 67), { Color = Color3.fromRGB(95, 100, 98) })
	StationDecor.CRT(station, CFrame.new(0, 3, 67) * CFrame.Angles(0, math.rad(180), 0), StationDecor.Colors.PhosphorAmber, {
		"СОЮЗ-ОРБИТА 7",
		"O2 ........ OK",
		"ПИТАНИЕ ... 61%",
		"ERR 0x3F: SECTOR 4",
	})

	-- Cadáver de prueba (en el pasillo sur, al este)
	local corpse = part(station, "Corpse", Vector3.new(5, 1, 2), Vector3.new(75, 0.5, 45), {
		Color = Color3.fromRGB(200, 200, 200),
	})
	CollectionService:AddTag(corpse, Types.Tags.Corpse)

	-- Armarios (R2): uno en cada sala, con la puerta (LookVector) hacia el centro de la sala
	local function locker(name: string, position: Vector3, facing: Vector3)
		local model = Instance.new("Model")
		model.Name = name
		local body = part(model, "Body", Vector3.new(4, 8, 3), position, {
			Color = Color3.fromRGB(70, 90, 80),
			Material = Enum.Material.DiamondPlate,
		})
		body.CFrame = CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z))
		local hide = part(model, "HidePoint", Vector3.new(1, 1, 1), position + Vector3.new(0, -1, 0), {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		hide.CFrame = body.CFrame * CFrame.new(0, -1, 0)
		model.PrimaryPart = body
		model.Parent = station
		CollectionService:AddTag(model, Types.Tags.HidingSpot)
	end
	locker("LockerA", Vector3.new(-96, 4, -10), Vector3.new(-60, 4, -10))
	locker("LockerB", Vector3.new(30, 4, -66), Vector3.new(30, 4, -30))
	locker("LockerSur", Vector3.new(-10, 4, 66), Vector3.new(-10, 4, 40))

	-- Esclusa abierta al espacio (R2) en el extremo oeste del pasillo sur
	local airlock = part(station, "AirlockVacuum", Vector3.new(20, WALL_HEIGHT, 30), Vector3.new(-88, WALL_HEIGHT / 2, 45), {
		Transparency = 0.85,
		Color = Color3.fromRGB(120, 180, 255),
		Material = Enum.Material.ForceField,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	CollectionService:AddTag(airlock, Types.Tags.VacuumZone)

	-- Recursos (R3): suficiente para fabricar una de cada cosa y algo más
	local pickups = {
		{ "Chatarra", Vector3.new(-70, 1, -40), 2 },
		{ "Quimicos", Vector3.new(-25, 1, -60), 2 },
		{ "Bateria", Vector3.new(-60, 1, 5), 1 },
		{ "Circuito", Vector3.new(-15, 1, 10), 1 },
		{ "Quimicos", Vector3.new(70, 1, -10), 2 },
		{ "Chatarra", Vector3.new(25, 1, -60), 2 },
		{ "Chatarra", Vector3.new(-30, 1, 60), 1 },
		{ "Bateria", Vector3.new(60, 1, 60), 1 },
		{ "Circuito", Vector3.new(78, 1, 30), 1 },
	}
	local pickupColors = {
		Chatarra = Color3.fromRGB(150, 150, 140),
		Quimicos = Color3.fromRGB(120, 220, 90),
		Bateria = Color3.fromRGB(240, 200, 60),
		Circuito = Color3.fromRGB(60, 170, 230),
	}
	for i, data in pickups do
		local pickup = part(station, "Pickup_" .. data[1] .. i, Vector3.new(1.5, 1.5, 1.5), data[2], {
			Color = pickupColors[data[1]],
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		pickup:SetAttribute("Resource", data[1])
		pickup:SetAttribute("Amount", data[3])
		CollectionService:AddTag(pickup, Types.Tags.ResourcePickup)
	end

	-- Atmósfera: oscuridad casi total azul-violeta (R4). Technology = Future se fija en default.project.json
	-- (no es modificable desde scripts).
	-- Iluminacion tenue calida estilo DOORS (totalmente visible y navegable)
	Lighting.ClockTime = 14
	Lighting.Brightness = 1.0
	Lighting.Ambient = Color3.fromRGB(70, 64, 58)
	Lighting.OutdoorAmbient = Color3.fromRGB(48, 44, 42)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ShadowSoftness = 0.2

	buildAlien(station, Vector3.new(60, 4, -40))

	print("[ASTRONAUTA SERVER] Nivel gris de pruebas construido (TestStation)")
	return true
end

return TestStationBuilder
