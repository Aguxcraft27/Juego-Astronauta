--!nonstrict
-- Instancia un Layout de ShipGen en Workspace.Ship y gestiona sus elementos interactivos (Etapa S1):
--   * Puertas (tag "ShipDoor", atributo AccessLevel): se abren solas si se acerca alguien con
--     Player.AccessLevel >= nivel. Las de nivel 0 se abren para todos.
--   * Ventilaciones (tag "ShipVent"): conducto de 4 studs con rejillas; ProximityPrompt "Arrastrarse"
--     que agacha al jugador y lo lleva al otro extremo (evento VentExited para la sospecha de S3).
--   * Tarjetas de acceso (tag "IdCard", atributo Level): Player.AccessLevel = max(actual, Level).
--   * Puntos semánticos (tag "ShipPoint", atributos Kind/RoomId/Sector) para la tripulación de S2.
--   * Semilla: Workspace.ShipSeed o os.time(); se publica en AstronautaRuntime.ShipSeed y el layout
--     serializado en AstronautaRuntime.ShipLayout (JSON, formato en ShipBuilder.Serialize).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local ShipGenShared = Shared:WaitForChild("ShipGen")
local LayoutGenerator = require(ShipGenShared:WaitForChild("LayoutGenerator"))
local Rng = require(ShipGenShared:WaitForChild("Rng"))
local CraftingConfig = require(Shared:WaitForChild("CraftingConfig"))
local RoomLibrary = require(script.Parent:WaitForChild("RoomLibrary"))
local PlayerStateService = require(script.Parent.Parent:WaitForChild("PlayerStateService"))

local P = RoomLibrary.Part

local ShipBuilder = {}

ShipBuilder.Tags = {
	Door = "ShipDoor",
	Vent = "ShipVent",
	IdCard = "IdCard",
	Point = "ShipPoint",
}

local DOOR_WIDTH, DOOR_HEIGHT = 10, 10
local ARCH_WIDTH, ARCH_HEIGHT = 14, 12
local VENT_SIZE = 4
local WALL_T = 1
local DOOR_OPEN_DISTANCE = 9
local CRAWL_TIME = 1.2

local DIR = {
	E = { 1, 0 },
	W = { -1, 0 },
	S = { 0, 1 },
	N = { 0, -1 },
}

local ventExitedEvent = Instance.new("BindableEvent")
ShipBuilder.VentExited = ventExitedEvent.Event -- (character, roomId, position)

local currentLayout = nil
local runtimeFolder: Folder

-- Utilidades -------------------------------------------------------------------------------
local function roomsById(layout): { [number]: any }
	local map = {}
	for _, room in layout.rooms do
		map[room.id] = room
	end
	return map
end

local function cellKey(x: number, z: number): string
	return x .. "," .. z
end

-- Clave canónica de la frontera entre la celda (x,z) y su vecina en dir
local function boundaryKey(x: number, z: number, dir: string): string
	if dir == "W" then
		return cellKey(x - 1, z) .. "E"
	elseif dir == "N" then
		return cellKey(x, z - 1) .. "S"
	end
	return cellKey(x, z) .. dir
end

-- Pared a lo largo de una frontera. "axis" = "X" (pared a lo largo de X, separa en Z) o "Z".
-- Construye la pared completa con un hueco opcional centrado: opening = {width, height, bottom}
local function buildWall(parent: Instance, center: Vector3, axis: string, length: number, height: number, opening)
	local function seg(alongOffset: number, alongLen: number, y0: number, y1: number, name: string)
		if alongLen <= 0.05 or y1 - y0 <= 0.05 then
			return
		end
		local size = if axis == "X"
			then Vector3.new(alongLen, y1 - y0, WALL_T)
			else Vector3.new(WALL_T, y1 - y0, alongLen)
		local offset = if axis == "X" then Vector3.new(alongOffset, 0, 0) else Vector3.new(0, 0, alongOffset)
		P(parent, name, size, CFrame.new(center + offset + Vector3.new(0, (y0 + y1) / 2, 0)))
	end
	if not opening then
		seg(0, length, 0, height, "Wall")
		return
	end
	local w, h, bottom = opening.width, opening.height, opening.bottom or 0
	local side = (length - w) / 2
	seg(-(w / 2 + side / 2), side, 0, height, "Wall")
	seg(w / 2 + side / 2, side, 0, height, "Wall")
	seg(0, w, bottom + h, height, "Lintel")
	seg(0, w, 0, bottom, "Sill")
end

-- Construcción -------------------------------------------------------------------------------
local function buildRoomShell(shipModel: Instance, layout, room, origin: Vector3): Model
	local C = layout.cellSize
	local H = layout.wallHeight
	local model = Instance.new("Model")
	model.Name = ("Room_%02d_%s"):format(room.id, room.sector)
	model:SetAttribute("RoomId", room.id)
	model:SetAttribute("Sector", room.sector)
	model:SetAttribute("AccessLevel", room.level)

	-- Suelo y techo de toda la sala (una parte cada uno)
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, c in room.cells do
		minX, maxX = math.min(minX, c[1]), math.max(maxX, c[1])
		minZ, maxZ = math.min(minZ, c[2]), math.max(maxZ, c[2])
	end
	local centerX = (minX + maxX) / 2 * C
	local centerZ = (minZ + maxZ) / 2 * C
	local sizeX = (maxX - minX + 1) * C
	local sizeZ = (maxZ - minZ + 1) * C
	P(model, "Floor", Vector3.new(sizeX, 1, sizeZ), CFrame.new(origin + Vector3.new(centerX, -0.5, centerZ)), {
		Color = RoomLibrary.FloorColorFor(room.sector),
		Material = Enum.Material.DiamondPlate,
	})
	P(model, "Ceiling", Vector3.new(sizeX, 1, sizeZ), CFrame.new(origin + Vector3.new(centerX, H + 0.5, centerZ)), {
		Color = RoomLibrary.TrimColor,
		CastShadow = false,
	})

	-- Una lámpara por celda
	for _, c in room.cells do
		RoomLibrary.CeilingLamp(model, origin + Vector3.new(c[1] * C, H - 0.4, c[2] * C), room.sector)
	end

	-- Rótulo del sector sobre la pared
	model.Parent = shipModel
	return model
end

local function buildConnector(parent: Instance, edge, center: Vector3, axis: string, layout)
	local H = layout.wallHeight
	local C = layout.cellSize
	if edge.type == "Puerta" then
		buildWall(parent, center, axis, C, H, { width = DOOR_WIDTH, height = DOOR_HEIGHT })
		local size = if axis == "X" then Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 0.6) else Vector3.new(0.6, DOOR_HEIGHT, DOOR_WIDTH)
		local door = P(parent, "Door", size, CFrame.new(center + Vector3.new(0, DOOR_HEIGHT / 2, 0)), {
			Color = RoomLibrary.LevelColor[edge.level]:Lerp(Color3.fromRGB(60, 60, 60), 0.55),
			Material = Enum.Material.DiamondPlate,
		})
		door:SetAttribute("AccessLevel", edge.level)
		door:SetAttribute("EdgeId", edge.id)
		CollectionService:AddTag(door, ShipBuilder.Tags.Door)
		-- Franja de nivel sobre el hueco + cartel
		local signSize = if axis == "X" then Vector3.new(DOOR_WIDTH, 1.6, 0.3) else Vector3.new(0.3, 1.6, DOOR_WIDTH)
		local sign = P(parent, "DoorSign", signSize, CFrame.new(center + Vector3.new(0, DOOR_HEIGHT + 1.2, 0)), {
			Color = RoomLibrary.LevelColor[edge.level],
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
		if axis == "Z" then
			sign.CFrame = sign.CFrame * CFrame.Angles(0, math.rad(90), 0)
			sign.Size = Vector3.new(DOOR_WIDTH, 1.6, 0.3)
		end
		if edge.level > 0 then
			RoomLibrary.LevelSign(sign, edge.level)
		end
	elseif edge.type == "Pasillo" then
		buildWall(parent, center, axis, C, H, { width = ARCH_WIDTH, height = ARCH_HEIGHT })
	elseif edge.type == "Ventilacion" then
		buildWall(parent, center, axis, C, H, { width = VENT_SIZE, height = VENT_SIZE })
		-- Conducto: 3 studs a cada lado de la pared, 4 de alto
		local d = DIR[edge.dir]
		local along = Vector3.new(d[1], 0, d[2]) -- atraviesa la pared
		local side = Vector3.new(d[2], 0, d[1]) -- a lo largo de la pared
		local ductLen = 6
		local vent = Instance.new("Model")
		vent.Name = "Vent_" .. edge.id
		local roofSize = Vector3.new(math.abs(along.X) * ductLen + math.abs(side.X) * (VENT_SIZE + 1), 0.4,
			math.abs(along.Z) * ductLen + math.abs(side.Z) * (VENT_SIZE + 1))
		P(vent, "DuctRoof", roofSize, CFrame.new(center + Vector3.new(0, VENT_SIZE + 0.2, 0)), { Color = Color3.fromRGB(110, 115, 115) })
		for _, s in { -1, 1 } do
			local wallSize = Vector3.new(math.abs(along.X) * ductLen + math.abs(side.X) * 0.4, VENT_SIZE,
				math.abs(along.Z) * ductLen + math.abs(side.Z) * 0.4)
			P(vent, "DuctSide", wallSize, CFrame.new(center + side * s * (VENT_SIZE / 2 + 0.3) + Vector3.new(0, VENT_SIZE / 2, 0)), {
				Color = Color3.fromRGB(110, 115, 115),
			})
		end
		-- Rejillas en ambos extremos (visuales) + prompt para arrastrarse
		for _, s in { -1, 1 } do
			local grateSize = Vector3.new(math.abs(side.X) * VENT_SIZE + 0.2, VENT_SIZE, math.abs(side.Z) * VENT_SIZE + 0.2)
			local grate = P(vent, "Grate", grateSize, CFrame.new(center + along * s * (ductLen / 2) + Vector3.new(0, VENT_SIZE / 2, 0)), {
				Color = Color3.fromRGB(40, 42, 44),
				Material = Enum.Material.DiamondPlate,
				Transparency = 0.35,
				CanCollide = true,
			})
			grate:SetAttribute("Side", s) -- -1 = lado de la sala A (edge.a), +1 = lado de la sala B
			grate:SetAttribute("EdgeId", edge.id)
			CollectionService:AddTag(grate, ShipBuilder.Tags.Vent)
		end
		vent.Parent = parent
	end
end

local function pointCFrame(origin: Vector3, point): CFrame
	local pos = origin + Vector3.new(point.x, 0, point.z)
	local fx, fz = point.facingX or 0, point.facingZ or -1
	-- Esquinas: alinear con un eje (los props quedan paralelos a la pared, no en diagonal)
	if math.abs(fx) > 0 and math.abs(fz) > 0 then
		if (point.room + math.floor(point.x)) % 2 == 0 then
			fz = 0
		else
			fx = 0
		end
	end
	local dir = Vector3.new(fx, 0, fz)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(pos, pos + dir.Unit)
end

function ShipBuilder.Build(seed: number): Model
	local layout = LayoutGenerator.Generate(seed)
	currentLayout = layout
	local C = layout.cellSize
	local H = layout.wallHeight
	local origin = Vector3.new(0, 0, 0)
	local byId = roomsById(layout)

	local old = Workspace:FindFirstChild("Ship")
	if old then
		old:Destroy()
	end
	local ship = Instance.new("Model")
	ship.Name = "Ship"
	ship:SetAttribute("Seed", seed)

	local occ = {}
	local roomModels = {}
	for _, room in layout.rooms do
		for _, c in room.cells do
			occ[cellKey(c[1], c[2])] = room.id
		end
		roomModels[room.id] = buildRoomShell(ship, layout, room, origin)
	end

	-- Conectores por frontera
	local connectorByBoundary = {}
	for _, edge in layout.edges do
		connectorByBoundary[boundaryKey(edge.cell[1], edge.cell[2], edge.dir)] = edge
	end

	-- Paredes: cada frontera una vez
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = ship
	local done = {}
	for _, room in layout.rooms do
		for _, c in room.cells do
			for dirName, d in DIR do
				local nx, nz = c[1] + d[1], c[2] + d[2]
				local neighbour = occ[cellKey(nx, nz)]
				local bkey = boundaryKey(c[1], c[2], dirName)
				if neighbour ~= room.id and not done[bkey] then
					done[bkey] = true
					local center = origin + Vector3.new((c[1] + d[1] * 0.5) * C, 0, (c[2] + d[2] * 0.5) * C)
					local axis = if d[1] ~= 0 then "Z" else "X"
					local edge = connectorByBoundary[bkey]
					if edge then
						buildConnector(walls, edge, center, axis, layout)
					else
						buildWall(walls, center, axis, C, H, nil)
					end
				end
			end
		end
	end

	-- Puntos semánticos + props
	local pointsFolder = Instance.new("Folder")
	pointsFolder.Name = "Points"
	pointsFolder.Parent = ship
	for _, point in layout.points do
		local room = byId[point.room]
		local cf = pointCFrame(origin, point)
		local marker = P(pointsFolder, point.kind, Vector3.new(1, 1, 1), cf + Vector3.new(0, 0.5, 0), {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		marker:SetAttribute("Kind", point.kind)
		marker:SetAttribute("RoomId", point.room)
		marker:SetAttribute("Sector", room.sector)
		if point.edge then
			marker:SetAttribute("EdgeId", point.edge)
		end
		CollectionService:AddTag(marker, ShipBuilder.Tags.Point)
		RoomLibrary.Prop(roomModels[point.room], point.kind, cf, room.sector)
	end

	-- Tarjetas de acceso
	for _, card in layout.cards do
		local pos = origin + Vector3.new(card.x, 0, card.z)
		P(ship, "IdCardStand", Vector3.new(2, 3, 2), CFrame.new(pos + Vector3.new(0, 1.5, 0)), { Color = RoomLibrary.TrimColor })
		local idCard = P(ship, "IdCard_L" .. card.level, Vector3.new(1.2, 0.08, 0.8), CFrame.new(pos + Vector3.new(0, 3.1, 0)), {
			Color = RoomLibrary.LevelColor[card.level],
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		idCard:SetAttribute("Level", card.level)
		idCard:SetAttribute("RoomId", card.room)
		local glow = Instance.new("PointLight")
		glow.Color = RoomLibrary.LevelColor[card.level]
		glow.Range = 6
		glow.Brightness = 1
		glow.Shadows = false
		glow.Parent = idCard
		CollectionService:AddTag(idCard, ShipBuilder.Tags.IdCard)
	end

	-- Recursos de crafteo: 6-8 en salas aleatorias (deterministas por semilla)
	do
		local rng = Rng.new(seed + 777)
		local count = rng:NextInt(6, 8)
		local candidates = {}
		for _, room in layout.rooms do
			if room.id ~= layout.spawnRoom then
				table.insert(candidates, room)
			end
		end
		rng:Shuffle(candidates)
		local colors = {
			Chatarra = Color3.fromRGB(150, 150, 140),
			Quimicos = Color3.fromRGB(120, 220, 90),
			Bateria = Color3.fromRGB(240, 200, 60),
			Circuito = Color3.fromRGB(60, 170, 230),
		}
		for i = 1, math.min(count, #candidates) do
			local room = candidates[i]
			local slot = table.remove(room.freeSlots)
			local c = room.cells[1]
			local pos = if slot then Vector3.new(slot.x, 0, slot.z) else Vector3.new(c[1] * C + 6, 0, c[2] * C - 6)
			local resource = rng:Pick(CraftingConfig.Resources)
			local pickup = P(ship, "Pickup_" .. resource, Vector3.new(1.5, 1.5, 1.5), CFrame.new(origin + pos + Vector3.new(0, 1, 0)), {
				Color = colors[resource],
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			pickup:SetAttribute("Resource", resource)
			pickup:SetAttribute("Amount", rng:NextInt(1, 2))
			CollectionService:AddTag(pickup, Types.Tags.ResourcePickup)
		end
	end

	-- Spawn en Dormitorios
	local spawnRoom = byId[layout.spawnRoom]
	local sc = spawnRoom.cells[1]
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ShipSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(5, 0.4, 5)
	spawn.CFrame = CFrame.new(origin + Vector3.new(sc[1] * C, 0.2, sc[2] * C))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = ship

	ship.Parent = Workspace

	-- Publicar semilla y layout
	runtimeFolder:SetAttribute("ShipSeed", seed)
	runtimeFolder:SetAttribute("ShipLayout", ShipBuilder.Serialize(layout))

	local partCount = 0
	for _, d in ship:GetDescendants() do
		if d:IsA("BasePart") then
			partCount += 1
		end
	end
	print(("[SHIPGEN] Nave generada · semilla %d (reintento %d) · %d salas · %d conexiones · %d partes"):format(
		seed, layout.attempt, #layout.rooms, #layout.edges, partCount))
	return ship
end

-- Formato de ShipLayout (JSON) para el minimapa de depuración:
-- {
--   "seed": number, "cell": number (studs por celda; celda (x,z) centrada en (x*cell, z*cell)),
--   "spawn": roomId,
--   "rooms": [ { "id", "sector", "level", "cells": [[x,z],...] } ],
--   "edges": [ { "id", "a", "b", "type": "Puerta"|"Pasillo"|"Ventilacion", "level", "cell": [x,z], "dir": "N|E|S|W" } ],
--   "cards": [ { "level", "room", "x", "z" } ]       (x/z en studs, mismo origen)
-- }
function ShipBuilder.Serialize(layout): string
	local rooms, edges, cards = {}, {}, {}
	for _, r in layout.rooms do
		table.insert(rooms, { id = r.id, sector = r.sector, level = r.level, cells = r.cells })
	end
	for _, e in layout.edges do
		table.insert(edges, { id = e.id, a = e.a, b = e.b, type = e.type, level = e.level, cell = e.cell, dir = e.dir })
	end
	for _, c in layout.cards do
		table.insert(cards, { level = c.level, room = c.room, x = c.x, z = c.z })
	end
	return HttpService:JSONEncode({
		seed = layout.seed,
		cell = layout.cellSize,
		spawn = layout.spawnRoom,
		rooms = rooms,
		edges = edges,
		cards = cards,
	})
end

function ShipBuilder.GetLayout()
	return currentLayout
end

-- Interacción en tiempo de ejecución --------------------------------------------------------------
local function playerLevel(player: Player): number
	return player:GetAttribute("AccessLevel") or 0
end

local function updateDoors()
	local roots = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			table.insert(roots, { pos = root.Position, level = playerLevel(player) })
		end
	end
	for _, door in CollectionService:GetTagged(ShipBuilder.Tags.Door) do
		local need = door:GetAttribute("AccessLevel") or 0
		local open = false
		for _, r in roots do
			if r.level >= need and (r.pos - door.Position).Magnitude <= DOOR_OPEN_DISTANCE then
				open = true
				break
			end
		end
		if door:GetAttribute("Open") ~= open then
			door:SetAttribute("Open", open)
			door.CanCollide = not open
			door.Transparency = if open then 0.9 else 0
		end
	end
end

local function setupVentPrompt(grate: BasePart)
	if grate:FindFirstChild("VentPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VentPrompt"
	prompt.ActionText = "Arrastrarse por la ventilación"
	prompt.ObjectText = "Rejilla"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Parent = grate

	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or character:GetAttribute("InVent") or character:GetAttribute("HiddenInSpot")
			or character:GetAttribute("Captured") then
			return
		end
		local edgeId = grate:GetAttribute("EdgeId")
		local side = grate:GetAttribute("Side")
		-- Rejilla del otro extremo
		local target
		for _, other in CollectionService:GetTagged(ShipBuilder.Tags.Vent) do
			if other ~= grate and other:GetAttribute("EdgeId") == edgeId then
				target = other
			end
		end
		if not target or not currentLayout then
			return
		end
		local edge = currentLayout.edges[edgeId]
		local exitRoom = if side == -1 then edge.b else edge.a
		-- Dirección de salida: alejándose de la pared, hacia la sala de destino
		local away = (target.Position - grate.Position)
		away = Vector3.new(away.X, 0, away.Z).Unit
		local exitPos = target.Position + away * 3 + Vector3.new(0, 1, 0)

		-- Arrastrarse: agachado, oculto en el conducto un instante, sale al otro lado
		character:SetAttribute("InVent", true)
		PlayerStateService.SetFlashlight(character, false)
		root.Anchored = true
		task.wait(CRAWL_TIME)
		if character.Parent == nil then
			return
		end
		character:PivotTo(CFrame.lookAt(exitPos, exitPos + away))
		root.Anchored = false
		character:SetAttribute("InVent", nil)
		-- Sale agachado (el cliente sincroniza el modo al recibir el atributo MoveMode)
		character:SetAttribute("MoveMode", Types.MoveMode.Crouch)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = require(Shared:WaitForChild("AlienConfig")).Player.CrouchSpeed
		end
		ventExitedEvent:Fire(character, exitRoom, exitPos)
	end)
end

local function setupIdCard(card: BasePart)
	if card:FindFirstChild("CardPrompt") then
		return
	end
	local level = card:GetAttribute("Level") or 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CardPrompt"
	prompt.ActionText = "Recoger identificación"
	prompt.ObjectText = RoomLibrary.LevelName[level] or ("Nivel " .. level)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = card
	local taken = false
	prompt.Triggered:Connect(function(player: Player)
		if taken then
			return
		end
		taken = true
		player:SetAttribute("AccessLevel", math.max(playerLevel(player), level))
		print(("[SHIPGEN] %s obtuvo identificación de nivel %d"):format(player.Name, level))
		card:Destroy()
	end)
end

-- Init -------------------------------------------------------------------------------------------
function ShipBuilder.Init(folder: Folder)
	runtimeFolder = folder

	local seed = Workspace:GetAttribute("ShipSeed")
	if typeof(seed) ~= "number" then
		seed = os.time()
	end
	ShipBuilder.Build(seed)

	local function onPlayer(player: Player)
		if player:GetAttribute("AccessLevel") == nil then
			player:SetAttribute("AccessLevel", 0)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	for _, grate in CollectionService:GetTagged(ShipBuilder.Tags.Vent) do
		setupVentPrompt(grate)
	end
	CollectionService:GetInstanceAddedSignal(ShipBuilder.Tags.Vent):Connect(setupVentPrompt)
	for _, card in CollectionService:GetTagged(ShipBuilder.Tags.IdCard) do
		setupIdCard(card)
	end
	CollectionService:GetInstanceAddedSignal(ShipBuilder.Tags.IdCard):Connect(setupIdCard)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(step)
		accumulator += step
		if accumulator >= 0.15 then
			accumulator = 0
			updateDoors()
		end
	end)

	-- Depuración (solo Studio): regenerar la nave con otra semilla o una concreta
	if RunService:IsStudio() then
		local regen = Instance.new("RemoteEvent")
		regen.Name = "RegenerateShip"
		regen.Parent = folder
		regen.OnServerEvent:Connect(function(_player: Player, requestedSeed: any)
			local newSeed = if typeof(requestedSeed) == "number" then math.floor(requestedSeed) else os.time() + math.random(1, 100000)
			ShipBuilder.Build(newSeed)
			for _, p in Players:GetPlayers() do
				p:SetAttribute("AccessLevel", 0)
				p:LoadCharacter()
			end
		end)
	end
end

return ShipBuilder
