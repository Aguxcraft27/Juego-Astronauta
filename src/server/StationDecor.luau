--!nonstrict
-- Props analógicos de los 90 / estación soviética (Milestone R4), construidos con Parts.
-- CRT con pantalla de fósforo (SurfaceGui), módulo habitacional (literas, mesa de fórmica, latas, tazas,
-- cómoda de madera con televisor) y focos cálidos aislados con sombras duras.

local TweenService = game:GetService("TweenService")

local StationDecor = {}

StationDecor.Colors = {
	CrtCase = Color3.fromRGB(196, 188, 168), -- plástico beige amarillento
	CrtBezel = Color3.fromRGB(40, 40, 38),
	PhosphorGreen = Color3.fromRGB(90, 255, 120),
	PhosphorAmber = Color3.fromRGB(255, 176, 50),
	Wood = Color3.fromRGB(105, 70, 42),
	Formica = Color3.fromRGB(200, 185, 150),
	Metal = Color3.fromRGB(95, 100, 98),
	WornGreen = Color3.fromRGB(80, 96, 82),
	Mattress = Color3.fromRGB(150, 160, 175),
	WarmLight = Color3.fromRGB(255, 186, 120),
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Material = Enum.Material.SmoothPlastic
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
StationDecor.Part = part

-- Monitor CRT. "cframe" = centro de la base del monitor, mirando hacia su LookVector.
-- Devuelve el Model y la carcasa (para poner tags, p. ej. AlarmConsole).
function StationDecor.CRT(parent: Instance, cframe: CFrame, phosphor: Color3, lines: { string }, scale: number?): (Model, Part)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "CRT"
	local C = StationDecor.Colors

	local body = cframe * CFrame.new(0, 1.6 * s, 0)
	local case = part(model, "Case", Vector3.new(3.4, 3.0, 2.2) * s, body * CFrame.new(0, 0, 0.3 * s), { Color = C.CrtCase })
	-- Parte trasera del tubo (más estrecha)
	part(model, "Tube", Vector3.new(2.6, 2.3, 1.6) * s, body * CFrame.new(0, 0, 1.9 * s), { Color = C.CrtCase })
	part(model, "Bezel", Vector3.new(3.0, 2.5, 0.12) * s, body * CFrame.new(0, 0.1 * s, -0.8 * s), { Color = C.CrtBezel })
	local screen = part(model, "Screen", Vector3.new(2.5, 1.95, 0.1) * s, body * CFrame.new(0, 0.15 * s, -0.86 * s), {
		Color = phosphor:Lerp(Color3.new(0, 0, 0), 0.75),
		Material = Enum.Material.Glass,
		Reflectance = 0.05,
	})
	-- Botones y rejilla
	part(model, "Knob", Vector3.new(0.25, 0.25, 0.1) * s, body * CFrame.new(1.25 * s, -1.15 * s, -0.83 * s), {
		Color = C.CrtBezel,
	})
	part(model, "PowerLED", Vector3.new(0.12, 0.12, 0.05) * s, body * CFrame.new(0.9 * s, -1.15 * s, -0.83 * s), {
		Color = Color3.fromRGB(255, 60, 40),
		Material = Enum.Material.Neon,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.PixelsPerStud = 60
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = screen

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = phosphor:Lerp(Color3.new(0, 0, 0), 0.9)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -16, 1, -12)
	text.Position = UDim2.fromOffset(8, 6)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Code
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextColor3 = phosphor
	text.Text = table.concat(lines, "\n")
	text.Parent = bg

	-- Scanlines
	for i = 0, 11 do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, 0, 0, 2)
		line.Position = UDim2.fromScale(0, i / 12)
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = 0.6
		line.BorderSizePixel = 0
		line.ZIndex = 2
		line.Parent = bg
	end

	-- Brillo del fósforo hacia la sala
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Color = phosphor
	glow.Brightness = 1.2
	glow.Range = 10
	glow.Angle = 100
	glow.Parent = screen

	-- Parpadeo suave del tubo
	TweenService:Create(glow, TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true, 2.5 + math.random()), {
		Brightness = 0.7,
	}):Play()

	model.PrimaryPart = case
	model.Parent = parent
	return model, case
end

-- Foco cálido colgante con sombras duras (luz puntual que "corta" la oscuridad).
function StationDecor.HangingLamp(parent: Instance, position: Vector3, range: number?)
	local C = StationDecor.Colors
	part(parent, "LampCable", Vector3.new(0.1, 2, 0.1), CFrame.new(position + Vector3.new(0, 1.3, 0)), {
		Color = Color3.fromRGB(20, 20, 20),
		CanCollide = false,
	})
	local shade = part(parent, "LampShade", Vector3.new(0.6, 1.8, 1.8), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(60, 70, 60),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	local bulb = part(parent, "Bulb", Vector3.new(0.5, 0.5, 0.5), CFrame.new(position - Vector3.new(0, 0.4, 0)), {
		Shape = Enum.PartType.Ball,
		Color = C.WarmLight,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	-- Foco hacia abajo y luz ambiental omnidireccional tenue estilo DOORS
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Color = C.WarmLight
	spot.Brightness = 2.2
	spot.Range = range or 32
	spot.Angle = 85
	spot.Shadows = true
	spot.Parent = bulb

	local point = Instance.new("PointLight")
	point.Name = "OmniLight"
	point.Color = C.WarmLight
	point.Brightness = 1.5
	point.Range = range or 36
	point.Shadows = false -- sin sombras para un relleno suave como DOORS
	point.Parent = bulb

	return shade
end

-- Lámpara de mesa (pantalla de tela)
function StationDecor.TableLamp(parent: Instance, base: Vector3)
	local C = StationDecor.Colors
	part(parent, "LampBase", Vector3.new(0.5, 0.9, 0.9), CFrame.new(base + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)), {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(50, 35, 30),
	})
	local shade = part(parent, "LampShade", Vector3.new(1.0, 1.4, 1.4), CFrame.new(base + Vector3.new(0, 1.35, 0)) * CFrame.Angles(0, 0, math.rad(90)), {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(110, 100, 140),
		Material = Enum.Material.Fabric,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = C.WarmLight
	light.Brightness = 1.6
	light.Range = 14
	light.Shadows = true
	light.Parent = shade
end

-- Módulo habitacional: "origin" = esquina del área, mirando hacia +X (fondo contra la pared en -Z).
function StationDecor.BuildRestArea(parent: Instance, origin: CFrame)
	local C = StationDecor.Colors
	local area = Instance.new("Model")
	area.Name = "RestArea"
	area.Parent = parent

	-- Literas (2 niveles)
	local bunk = origin * CFrame.new(4, 0, 3)
	for _, x in { -1.6, 1.6 } do
		for _, z in { -3.2, 3.2 } do
			part(area, "BunkPost", Vector3.new(0.3, 8, 0.3), bunk * CFrame.new(x, 4, z), { Color = C.Metal, Material = Enum.Material.Metal })
		end
	end
	for _, y in { 1.4, 5.2 } do
		part(area, "BunkFrame", Vector3.new(3.4, 0.3, 6.8), bunk * CFrame.new(0, y, 0), { Color = C.Metal, Material = Enum.Material.Metal })
		part(area, "Mattress", Vector3.new(3.0, 0.6, 6.4), bunk * CFrame.new(0, y + 0.45, 0), {
			Color = C.Mattress,
			Material = Enum.Material.Fabric,
		})
		part(area, "Pillow", Vector3.new(2.2, 0.4, 1.0), bunk * CFrame.new(0, y + 0.95, -2.5), {
			Color = Color3.fromRGB(215, 210, 200),
			Material = Enum.Material.Fabric,
		})
	end
	-- Manta arrugada en la litera de abajo
	part(area, "Blanket", Vector3.new(3.1, 0.25, 3.2), bunk * CFrame.new(0.05, 2.35, 1.4) * CFrame.Angles(0, math.rad(4), math.rad(2)), {
		Color = Color3.fromRGB(90, 60, 70),
		Material = Enum.Material.Fabric,
	})

	-- Mesa de fórmica con latas y tazas
	local tableCf = origin * CFrame.new(13, 0, 6)
	part(area, "TableTop", Vector3.new(6, 0.3, 3.5), tableCf * CFrame.new(0, 3, 0), {
		Color = C.Formica,
		Material = Enum.Material.SmoothPlastic,
	})
	for _, x in { -2.7, 2.7 } do
		for _, z in { -1.5, 1.5 } do
			part(area, "TableLeg", Vector3.new(0.25, 3, 0.25), tableCf * CFrame.new(x, 1.5, z), { Color = C.Metal, Material = Enum.Material.Metal })
		end
	end
	local canColors = { Color3.fromRGB(180, 40, 30), Color3.fromRGB(200, 200, 205), Color3.fromRGB(60, 110, 60) }
	for i, offset in { Vector3.new(-1.8, 0, -0.6), Vector3.new(-1.2, 0, 0.7), Vector3.new(0.3, 0, -0.9) } do
		part(area, "Can", Vector3.new(0.9, 0.55, 0.55), tableCf * CFrame.new(offset + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), {
			Shape = Enum.PartType.Cylinder,
			Color = canColors[i],
			Material = Enum.Material.Metal,
			Reflectance = 0.15,
		})
	end
	-- Lata tumbada
	part(area, "CanFallen", Vector3.new(0.9, 0.55, 0.55), tableCf * CFrame.new(1.0, 3.43, 0.6) * CFrame.Angles(0, math.rad(30), 0), {
		Shape = Enum.PartType.Cylinder,
		Color = canColors[2],
		Material = Enum.Material.Metal,
	})
	for _, offset in { Vector3.new(1.9, 0, -0.4), Vector3.new(2.3, 0, 0.8) } do
		part(area, "Mug", Vector3.new(0.7, 0.65, 0.65), tableCf * CFrame.new(offset + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), {
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(220, 215, 200),
		})
	end
	-- Sillas
	for _, x in { -1.5, 1.5 } do
		local chair = tableCf * CFrame.new(x, 0, 2.8)
		part(area, "ChairSeat", Vector3.new(1.6, 0.25, 1.6), chair * CFrame.new(0, 1.8, 0), { Color = C.Wood })
		part(area, "ChairBack", Vector3.new(1.6, 1.8, 0.2), chair * CFrame.new(0, 2.8, 0.7), { Color = C.Wood })
		part(area, "ChairBase", Vector3.new(0.3, 1.8, 0.3), chair * CFrame.new(0, 0.9, 0), { Color = C.Metal })
	end

	-- Cómoda de madera con televisor CRT (ámbar) y lámpara de mesa
	local dresser = origin * CFrame.new(22, 0, 1.5)
	part(area, "Dresser", Vector3.new(7, 3.2, 2.6), dresser * CFrame.new(0, 1.6, 0), { Color = C.Wood, Material = Enum.Material.Wood })
	for i = -1, 1 do
		part(area, "Drawer", Vector3.new(2.0, 1.2, 0.08), dresser * CFrame.new(i * 2.25, 1.9, 1.33), {
			Color = C.Wood:Lerp(Color3.new(0, 0, 0), 0.15),
			Material = Enum.Material.Wood,
		})
		part(area, "Handle", Vector3.new(0.6, 0.12, 0.12), dresser * CFrame.new(i * 2.25, 1.9, 1.4), {
			Color = Color3.fromRGB(170, 150, 90),
			Material = Enum.Material.Metal,
		})
	end
	StationDecor.CRT(area, dresser * CFrame.new(-0.8, 3.2, 0) * CFrame.Angles(0, math.rad(180), 0), C.PhosphorAmber, {
		"КАНАЛ 3",
		"",
		"ПРИЕМ...",
		"▒▒▓▒░▒▓▓▒",
	}, 0.9)
	StationDecor.TableLamp(area, (dresser * CFrame.new(2.6, 3.2, 0)).Position)

	-- Taquillas industriales desgastadas (decorativas, no son escondites)
	for i = 0, 2 do
		local locker = origin * CFrame.new(30 + i * 2.3, 0, 1.3)
		part(area, "OldLocker", Vector3.new(2.2, 7, 2.2), locker * CFrame.new(0, 3.5, 0), {
			Color = C.WornGreen:Lerp(Color3.fromRGB(110, 80, 50), math.random() * 0.3),
			Material = Enum.Material.CorrodedMetal,
		})
		for v = 0, 2 do
			part(area, "Vent", Vector3.new(1.4, 0.12, 0.05), locker * CFrame.new(0, 6.0 - v * 0.3, 1.11), {
				Color = Color3.fromRGB(30, 30, 30),
			})
		end
	end

	-- Foco cálido sobre la mesa
	StationDecor.HangingLamp(area, (tableCf * CFrame.new(0, 10.5, 0)).Position, 20)
	return area
end

return StationDecor
