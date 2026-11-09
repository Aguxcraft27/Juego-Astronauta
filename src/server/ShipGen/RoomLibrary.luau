--!nonstrict
-- Módulos 3D simples por sector (Etapa S1): luces, props y piezas de pared reutilizables.
-- Presupuesto: pocas partes por prop; luces de relleno SIN sombras (Radeon 610M).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Astronauta"):WaitForChild("Types"))
local StationDecor = require(script.Parent.Parent:WaitForChild("StationDecor"))

local RoomLibrary = {}

-- Paleta ---------------------------------------------------------------------------------
RoomLibrary.LightColor = {
	Default = Color3.fromRGB(110, 225, 205), -- azul verdoso general
	Ingenieria = Color3.fromRGB(255, 165, 70), -- ámbar
	Laboratorio = Color3.fromRGB(225, 238, 255), -- blanco frío
	Seguridad = Color3.fromRGB(255, 70, 60), -- rojo tenue
}
RoomLibrary.LightBrightness = { Default = 1.3, Seguridad = 0.9 }

RoomLibrary.FloorColor = {
	Default = Color3.fromRGB(58, 64, 68),
	Laboratorio = Color3.fromRGB(150, 155, 160),
	Ingenieria = Color3.fromRGB(70, 60, 50),
	Seguridad = Color3.fromRGB(60, 45, 48),
	Mando = Color3.fromRGB(45, 52, 66),
	Comedor = Color3.fromRGB(80, 72, 60),
}
RoomLibrary.WallColor = Color3.fromRGB(78, 88, 92)
RoomLibrary.TrimColor = Color3.fromRGB(40, 46, 50)
RoomLibrary.LevelColor = {
	[0] = Color3.fromRGB(120, 200, 140),
	[1] = Color3.fromRGB(240, 200, 60),
	[2] = Color3.fromRGB(80, 170, 255),
	[3] = Color3.fromRGB(255, 70, 60),
}
RoomLibrary.LevelName = {
	[0] = "PÚBLICO",
	[1] = "NIVEL 1 · TÉCNICO",
	[2] = "NIVEL 2 · CIENTÍFICO",
	[3] = "NIVEL 3 · SEGURIDAD",
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Material = Enum.Material.Metal
	p.Color = RoomLibrary.WallColor
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
RoomLibrary.Part = part

local function sectorValue(map: { [string]: any }, sector: string): any
	local v = map[sector]
	if v == nil then
		return map.Default
	end
	return v
end

function RoomLibrary.FloorColorFor(sector: string): Color3
	return sectorValue(RoomLibrary.FloorColor, sector)
end

-- Lámpara de techo (tag StationLamp: PowerGridService la apaga en los apagones)
function RoomLibrary.CeilingLamp(parent: Instance, position: Vector3, sector: string)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	local color = sectorValue(RoomLibrary.LightColor, sector)
	part(model, "Fixture", Vector3.new(6, 0.5, 2.4), CFrame.new(position + Vector3.new(0, 0.3, 0)), {
		Color = RoomLibrary.TrimColor,
		CastShadow = false,
	})
	local bulb = part(model, "Bulb", Vector3.new(5, 0.3, 1.6), CFrame.new(position), {
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 30
	light.Brightness = sectorValue(RoomLibrary.LightBrightness, sector)
	light.Shadows = false -- luz de relleno: sin sombras (rendimiento)
	light.Parent = bulb
	model.Parent = parent
	CollectionService:AddTag(model, Types.Tags.StationLamp)
	return model
end

-- Props por tipo de punto ---------------------------------------------------------------------
-- "cf": CFrame en el suelo, mirando hacia el interior de la sala (LookVector).

local function bed(parent: Instance, cf: CFrame)
	local frame = cf * CFrame.new(0, 0, 1.5)
	part(parent, "BedFrame", Vector3.new(4, 1.6, 7.5), frame * CFrame.new(0, 0.8, 0), {
		Color = Color3.fromRGB(70, 78, 82),
	})
	part(parent, "Mattress", Vector3.new(3.6, 0.6, 7), frame * CFrame.new(0, 1.9, 0), {
		Color = Color3.fromRGB(120, 135, 150),
		Material = Enum.Material.Fabric,
	})
	part(parent, "Pillow", Vector3.new(2.6, 0.5, 1.2), frame * CFrame.new(0, 2.4, 2.8), {
		Color = Color3.fromRGB(200, 200, 195),
		Material = Enum.Material.Fabric,
	})
end

local function seat(parent: Instance, cf: CFrame)
	part(parent, "Seat", Vector3.new(2, 0.4, 2), cf * CFrame.new(0, 1.8, 0), { Color = Color3.fromRGB(90, 70, 55) })
	part(parent, "SeatBack", Vector3.new(2, 2, 0.3), cf * CFrame.new(0, 2.9, 0.9), { Color = Color3.fromRGB(90, 70, 55) })
	part(parent, "SeatLeg", Vector3.new(0.4, 1.8, 0.4), cf * CFrame.new(0, 0.9, 0), { Color = RoomLibrary.TrimColor })
end

local function workStation(parent: Instance, cf: CFrame, sector: string)
	if sector == "Ingenieria" then
		-- Generador: cilindro con franja ámbar
		part(parent, "Generator", Vector3.new(6, 5, 5), cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), {
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(85, 80, 70),
		})
		part(parent, "GeneratorBand", Vector3.new(0.6, 5.2, 5.2), cf * CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)), {
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(255, 160, 50),
			Material = Enum.Material.Neon,
		})
	elseif sector == "Capsulas" then
		-- Cápsula de escape: cuerpo + cúpula de cristal
		part(parent, "PodBody", Vector3.new(5, 7, 5), cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), {
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(200, 195, 180),
			Material = Enum.Material.SmoothPlastic,
		})
		part(parent, "PodDome", Vector3.new(4.6, 4.6, 4.6), cf * CFrame.new(0, 7, 0), {
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(255, 140, 40),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		})
	elseif sector == "Almacen" then
		part(parent, "Crate", Vector3.new(4, 4, 4), cf * CFrame.new(0, 2, 0), { Color = Color3.fromRGB(110, 90, 60), Material = Enum.Material.WoodPlanks })
		part(parent, "Crate", Vector3.new(3, 3, 3), cf * CFrame.new(0.4, 5.5, 0.2) * CFrame.Angles(0, math.rad(20), 0), {
			Color = Color3.fromRGB(100, 85, 60),
			Material = Enum.Material.WoodPlanks,
		})
	elseif sector == "Comedor" then
		-- Mesa con bandejas
		part(parent, "Table", Vector3.new(6, 0.3, 3.5), cf * CFrame.new(0, 3, 0), { Color = Color3.fromRGB(200, 185, 150) })
		part(parent, "TableLeg", Vector3.new(0.6, 3, 0.6), cf * CFrame.new(0, 1.5, 0), { Color = RoomLibrary.TrimColor })
		part(parent, "Tray", Vector3.new(1.6, 0.15, 1.1), cf * CFrame.new(-1.5, 3.25, 0), { Color = Color3.fromRGB(150, 160, 160) })
		part(parent, "Tray", Vector3.new(1.6, 0.15, 1.1), cf * CFrame.new(1.4, 3.25, 0.3), { Color = Color3.fromRGB(150, 160, 160) })
	else
		-- Banco de trabajo (laboratorio blanco, resto metálico)
		local lab = sector == "Laboratorio"
		part(parent, "Bench", Vector3.new(6, 3, 2.6), cf * CFrame.new(0, 1.5, 0.6), {
			Color = lab and Color3.fromRGB(230, 232, 235) or Color3.fromRGB(95, 100, 98),
			Material = lab and Enum.Material.SmoothPlastic or Enum.Material.Metal,
		})
		if lab then
			part(parent, "Flask", Vector3.new(0.6, 1.2, 0.6), cf * CFrame.new(-1.6, 3.6, 0.6), {
				Shape = Enum.PartType.Cylinder,
				Color = Color3.fromRGB(120, 255, 170),
				Material = Enum.Material.Glass,
				Transparency = 0.3,
			}).CFrame = cf * CFrame.new(-1.6, 3.6, 0.6) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

local function terminal(parent: Instance, cf: CFrame, sector: string)
	part(parent, "TerminalDesk", Vector3.new(4.5, 3, 2.6), cf * CFrame.new(0, 1.5, 0.4), { Color = Color3.fromRGB(80, 85, 95) })
	local phosphor = if sector == "Laboratorio" or sector == "Ingenieria"
		then StationDecor.Colors.PhosphorAmber
		else StationDecor.Colors.PhosphorGreen
	local lines = {
		Seguridad = { "СЛУЖБА БЕЗОПАСНОСТИ", "> CÁMARAS: OK", "> ACCESOS: 3" },
		Mando = { "КОМАНДНЫЙ ПУНКТ", "> RUMBO: 214.7", "> CASCO: 92%" },
		Laboratorio = { "ЛАБОРАТОРИЯ", "> MUESTRA 7: ??", "> TEMP -40C" },
		Ingenieria = { "РЕАКТОР", "> NÚCLEO 61%", "> PRESIÓN OK" },
		Capsulas = { "СПАСАТЕЛЬНЫЕ", "> CÁPSULAS: 2", "> CÓDIGO: ****" },
	}
	-- El CRT mira hacia su LookVector; "cf" mira al interior de la sala
	StationDecor.CRT(parent, cf * CFrame.new(0, 3, 0.4), phosphor, lines[sector] or { "TERMINAL", "> _" }, 0.8)
end

local function locker(parent: Instance, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Locker"
	local body = part(model, "Body", Vector3.new(4, 8, 3), cf * CFrame.new(0, 4, 0.6), {
		Color = Color3.fromRGB(70, 90, 80),
		Material = Enum.Material.DiamondPlate,
	})
	part(model, "HidePoint", Vector3.new(1, 1, 1), cf * CFrame.new(0, 3, 0.6), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	-- ExitPoint delante de la puerta (el armario "mira" al interior de la sala)
	part(model, "ExitPoint", Vector3.new(1, 1, 1), cf * CFrame.new(0, 3, -3.5), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	model.PrimaryPart = body
	model.Parent = parent
	CollectionService:AddTag(model, Types.Tags.HidingSpot)
	return model
end

-- Construye el prop que corresponde a un punto semántico
function RoomLibrary.Prop(parent: Instance, kind: string, cf: CFrame, sector: string)
	if kind == "Bed" then
		bed(parent, cf)
	elseif kind == "Seat" then
		seat(parent, cf)
	elseif kind == "WorkStation" then
		workStation(parent, cf, sector)
	elseif kind == "Terminal" then
		terminal(parent, cf, sector)
	elseif kind == "HidingSpot" then
		locker(parent, cf)
	end
end

-- Cartel de nivel de acceso (SurfaceGui en ambas caras)
function RoomLibrary.LevelSign(target: BasePart, level: number)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0.3
		gui.PixelsPerStud = 25
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		label.BackgroundTransparency = 0.2
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = RoomLibrary.LevelColor[level] or Color3.new(1, 1, 1)
		label.Text = RoomLibrary.LevelName[level] or ("NIVEL " .. level)
		label.Parent = gui
	end
end

return RoomLibrary
