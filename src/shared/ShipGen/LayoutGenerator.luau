--!nonstrict
-- Generador de la nave (Etapa S1). Puro y determinista: sin APIs de Roblox.
-- Generate(seed) -> Layout
--
-- Grilla de celdas (CellSize studs). Salas de 1x1 o 2x1 (rotadas: w x h).
-- 1. Árbol: crecimiento tipo DOORS desde el spawn (Dormitorios); cada sala nueva se pega a una existente.
-- 2. Ciclos: 2-4 aristas extra entre salas vecinas no conectadas (rutas alternativas).
-- 3. Ventilaciones: 2-4 conductos (solo agachado, sin control de acceso) entre salas vecinas no conectadas;
--    una por cada sala de VentBypassSectors y las necesarias para que toda restringida tenga >= 2 accesos.
-- 4. Validator: tarjetas por nivel + completabilidad. Si falla, se reintenta con seed + n.
--
-- Coordenadas del Layout: X/Z en studs, con la celda (0,0) centrada en el origen. Sin Vector3
-- (tablas {x, z}) para poder ejecutarse en el CLI `luau`.

local function req(name: string): any
	if script then
		return (require :: any)((script :: any).Parent[name])
	end
	return (require :: any)("./" .. name)
end

local ShipConfig = req("ShipConfig")
local Rng = req("Rng")
local Validator = req("Validator")

local LayoutGenerator = {}

local DIRS = {
	{ name = "E", dx = 1, dz = 0 },
	{ name = "W", dx = -1, dz = 0 },
	{ name = "S", dx = 0, dz = 1 },
	{ name = "N", dx = 0, dz = -1 },
}

local function key(x: number, z: number): string
	return x .. "," .. z
end

type Room = { [string]: any }
type Edge = { [string]: any }

local function footprint(x: number, z: number, w: number, h: number): { { number } }
	local cells = {}
	for dx = 0, w - 1 do
		for dz = 0, h - 1 do
			table.insert(cells, { x + dx, z + dz })
		end
	end
	return cells
end

local function inBounds(cells: { { number } }, maxCoord: number): boolean
	for _, c in cells do
		if math.abs(c[1]) > maxCoord or math.abs(c[2]) > maxCoord then
			return false
		end
	end
	return true
end

-- Pares de celdas vecinas entre dos salas: { cellA, cellB, dir (de A hacia B) }
local function sharedBoundaries(a: Room, b: Room, occupied: { [string]: number }): { any }
	local result = {}
	for _, c in a.cells do
		for _, d in DIRS do
			local nx, nz = c[1] + d.dx, c[2] + d.dz
			if occupied[key(nx, nz)] == b.id then
				table.insert(result, { cell = { c[1], c[2] }, dir = d.name })
			end
		end
	end
	return result
end

local function tryGenerate(seed: number): (any?, string?)
	local cfg = ShipConfig
	local rng = Rng.new(seed)
	local rooms: { Room } = {}
	local edges: { Edge } = {}
	local occupied: { [string]: number } = {}
	local connected: { [string]: boolean } = {}

	local function pairKey(a: number, b: number): string
		return if a < b then a .. "-" .. b else b .. "-" .. a
	end

	local function addRoom(sector: string, cells: { { number } }, w: number, h: number): Room
		local room: Room = {
			id = #rooms + 1,
			sector = sector,
			level = cfg.AccessLevel[sector] or 0,
			x = cells[1][1],
			z = cells[1][2],
			w = w,
			h = h,
			rotation = if w >= h then 0 else 90,
			cells = cells,
		}
		table.insert(rooms, room)
		for _, c in cells do
			occupied[key(c[1], c[2])] = room.id
		end
		return room
	end

	local function addEdge(a: Room, b: Room, edgeType: string, extra: boolean): Edge?
		local boundaries = sharedBoundaries(a, b, occupied)
		if #boundaries == 0 then
			return nil
		end
		local boundary = rng:Pick(boundaries)
		local level = math.max(a.level, b.level)
		local t = edgeType
		if t == "Auto" then
			if level > 0 then
				t = "Puerta"
			else
				t = if rng:Chance(cfg.PublicCorridorChance) then "Pasillo" else "Puerta"
			end
		end
		local edge: Edge = {
			id = #edges + 1,
			a = a.id,
			b = b.id,
			type = t,
			level = if t == "Ventilacion" then 0 else level,
			cell = boundary.cell,
			dir = boundary.dir,
			extra = extra,
		}
		table.insert(edges, edge)
		connected[pairKey(a.id, b.id)] = true
		return edge
	end

	-- Lista de sectores: obligatorios (spawn primero, Capsulas al final) + relleno
	local total = rng:NextInt(cfg.RoomCountMin, cfg.RoomCountMax)
	local middle = {}
	for _, s in cfg.RequiredSectors do
		if s ~= cfg.SpawnSector and s ~= cfg.FinalSector then
			table.insert(middle, s)
		end
	end
	while #middle < total - 2 do
		table.insert(middle, rng:Pick(cfg.FillerSectors))
	end
	rng:Shuffle(middle)
	local order = { cfg.SpawnSector }
	for _, s in middle do
		table.insert(order, s)
	end
	table.insert(order, cfg.FinalSector)

	local function sizeFor(sector: string): (number, number)
		if rng:Chance(cfg.LargeRoomChance[sector] or 0.3) then
			if rng:Chance(0.5) then
				return 2, 1
			end
			return 1, 2
		end
		return 1, 1
	end

	-- 1. Árbol
	do
		local w, h = sizeFor(order[1])
		addRoom(order[1], footprint(0, 0, w, h), w, h)
	end
	for i = 2, #order do
		local sector = order[i]
		local placed = false
		for _ = 1, 30 do
			local w, h = sizeFor(sector)
			-- Candidatas: posiciones de la huella pegadas a alguna sala existente
			local best: { any } = {}
			local bestScore = -1
			for _, parent in rooms do
				for _, c in parent.cells do
					for _, d in DIRS do
						local nx, nz = c[1] + d.dx, c[2] + d.dz
						if occupied[key(nx, nz)] == nil then
							-- La celda vecina libre puede ser cualquier celda de la huella nueva
							for ox = 0, w - 1 do
								for oz = 0, h - 1 do
									local cells = footprint(nx - ox, nz - oz, w, h)
									local free = inBounds(cells, cfg.MaxCoord)
									if free then
										for _, fc in cells do
											if occupied[key(fc[1], fc[2])] ~= nil then
												free = false
												break
											end
										end
									end
									if free then
										-- Puntuación: vecinos distintos (más vecinos = más opciones de ciclo/ventilación)
										local neighbours: { [number]: boolean } = {}
										local count = 0
										for _, fc in cells do
											for _, d2 in DIRS do
												local id = occupied[key(fc[1] + d2.dx, fc[2] + d2.dz)]
												if id and not neighbours[id] then
													neighbours[id] = true
													count += 1
												end
											end
										end
										local score = count + rng:NextNumber() * 1.5
										if score > bestScore then
											bestScore = score
											best = { parent = parent, cells = cells }
										end
									end
								end
							end
						end
					end
				end
			end
			-- Padre: preferir salas recientes para alargar (estilo DOORS), si la mejor no lo es da igual
			if best.cells then
				local room = addRoom(sector, best.cells, w, h)
				-- El padre real: una sala vecina; si la "parent" candidata no es vecina directa, buscar una
				local parent = best.parent
				if #sharedBoundaries(room, parent, occupied) == 0 then
					parent = nil
				end
				if not parent then
					for _, other in rooms do
						if other.id ~= room.id and #sharedBoundaries(room, other, occupied) > 0 then
							parent = other
							break
						end
					end
				end
				if not parent then
					return nil, "sala sin padre"
				end
				addEdge(parent, room, "Auto", false)
				room.parent = parent.id
				placed = true
				break
			end
		end
		if not placed then
			return nil, "sin espacio para " .. sector
		end
	end

	local spawnRoom = rooms[1]

	-- Pares vecinos sin conectar
	local function freePairs(): { { Room } }
		local pairs = {}
		for i = 1, #rooms do
			for j = i + 1, #rooms do
				local a, b = rooms[i], rooms[j]
				if not connected[pairKey(a.id, b.id)] and #sharedBoundaries(a, b, occupied) > 0 then
					table.insert(pairs, { a, b })
				end
			end
		end
		return pairs
	end

	local function incident(room: Room): number
		local n = 0
		for _, e in edges do
			if e.a == room.id or e.b == room.id then
				n += 1
			end
		end
		return n
	end

	-- 2. Ciclos: primero dar segundo acceso a restringidas que no lo tienen y que NO tendrán ventilación obligatoria
	local bypass: { [string]: boolean } = {}
	for _, s in cfg.VentBypassSectors do
		bypass[s] = true
	end
	local extraTarget = rng:NextInt(cfg.ExtraEdgesMin, cfg.ExtraEdgesMax)
	local extraCount = 0
	for _, room in rooms do
		if room.level > 0 and not bypass[room.sector] and incident(room) < 2 and extraCount < extraTarget then
			local options = {}
			for _, p in freePairs() do
				if p[1] == room or p[2] == room then
					table.insert(options, p)
				end
			end
			if #options > 0 then
				local p = rng:Pick(options)
				addEdge(p[1], p[2], "Auto", true)
				extraCount += 1
			end
		end
	end
	while extraCount < extraTarget do
		local pairs = freePairs()
		if #pairs == 0 then
			break
		end
		local p = rng:Pick(pairs)
		addEdge(p[1], p[2], "Auto", true)
		extraCount += 1
	end

	-- 3. Ventilaciones
	local ventCount = 0
	local function addVent(room: Room): boolean
		local options = {}
		for _, p in freePairs() do
			if p[1] == room or p[2] == room then
				table.insert(options, p)
			end
		end
		if #options == 0 then
			return false
		end
		-- Preferir ventilación desde una sala de nivel inferior (la que "salta" la puerta)
		table.sort(options, function(x, y)
			local ox = if x[1] == room then x[2] else x[1]
			local oy = if y[1] == room then y[2] else y[1]
			if ox.level ~= oy.level then
				return ox.level < oy.level
			end
			return ox.id < oy.id
		end)
		local p = options[1]
		if rng:Chance(0.35) and #options > 1 then
			p = options[2]
		end
		local other = if p[1] == room then p[2] else p[1]
		addEdge(other, room, "Ventilacion", true)
		ventCount += 1
		return true
	end

	for _, room in rooms do
		if bypass[room.sector] then
			if not addVent(room) then
				return nil, "sin vecino para ventilar " .. room.sector
			end
		end
	end
	for _, room in rooms do
		if room.level > 0 and incident(room) < 2 then
			if not addVent(room) then
				return nil, "restringida sin segundo acceso: " .. room.sector
			end
		end
	end
	local ventTarget = rng:NextInt(cfg.VentsMin, cfg.VentsMax)
	while ventCount < ventTarget do
		local pairs = freePairs()
		if #pairs == 0 then
			break
		end
		local p = rng:Pick(pairs)
		addEdge(p[1], p[2], "Ventilacion", true)
		ventCount += 1
	end
	if ventCount > cfg.VentsMax then
		return nil, "demasiadas ventilaciones"
	end
	if ventCount < cfg.VentsMin then
		return nil, "pocas ventilaciones"
	end

	local layout = {
		seed = seed,
		cellSize = cfg.CellSize,
		wallHeight = cfg.WallHeight,
		rooms = rooms,
		edges = edges,
		spawnRoom = spawnRoom.id,
		cards = {},
		points = {},
	}

	local ok, reason = Validator.PlaceCardsAndValidate(layout, rng, cfg)
	if not ok then
		return nil, reason
	end

	-- 4. Puntos semánticos
	local C = cfg.CellSize
	local function cellCenter(c: { number }): (number, number)
		return c[1] * C, c[2] * C
	end
	local cornerOffsets = { { -0.32, -0.32 }, { 0.32, -0.32 }, { -0.32, 0.32 }, { 0.32, 0.32 } }
	local innerOffsets = { { -0.14, -0.14 }, { 0.14, -0.14 }, { -0.14, 0.14 }, { 0.14, 0.14 } }
	for _, room in rooms do
		local corners, inner = {}, {}
		for _, c in room.cells do
			local cx, cz = cellCenter(c)
			for _, o in cornerOffsets do
				table.insert(corners, { x = cx + o[1] * C, z = cz + o[2] * C, facingX = -o[1], facingZ = -o[2] })
			end
			for _, o in innerOffsets do
				table.insert(inner, { x = cx + o[1] * C, z = cz + o[2] * C, facingX = o[1], facingZ = o[2] })
			end
			table.insert(layout.points, { kind = "PatrolPoint", room = room.id, x = cx, z = cz })
		end
		rng:Shuffle(corners)
		rng:Shuffle(inner)
		local recipe = cfg.RoomRecipes[room.sector] or {}
		local kinds = {}
		for _, kind in cfg.PointKinds do
			for _ = 1, (recipe[kind] or 0) do
				table.insert(kinds, kind)
			end
		end
		for _, kind in kinds do
			local pool = if cfg.CornerKinds[kind] then corners else inner
			local slot = table.remove(pool) or table.remove(corners) or table.remove(inner)
			if slot then
				table.insert(layout.points, {
					kind = kind,
					room = room.id,
					x = slot.x,
					z = slot.z,
					facingX = slot.facingX,
					facingZ = slot.facingZ,
				})
			end
		end
		room.freeSlots = inner -- ranuras interiores libres (tarjetas, recursos)
	end

	-- Salidas de ventilación: un punto en cada lado del conducto
	for _, edge in edges do
		if edge.type == "Ventilacion" then
			local d
			for _, dd in DIRS do
				if dd.name == edge.dir then
					d = dd
				end
			end
			local cx, cz = cellCenter(edge.cell)
			local bx, bz = cx + d.dx * C / 2, cz + d.dz * C / 2
			table.insert(layout.points, { kind = "VentExit", room = edge.a, edge = edge.id,
				x = bx - d.dx * C * 0.15, z = bz - d.dz * C * 0.15 })
			table.insert(layout.points, { kind = "VentExit", room = edge.b, edge = edge.id,
				x = bx + d.dx * C * 0.15, z = bz + d.dz * C * 0.15 })
		end
	end

	-- Posición física de cada tarjeta: una ranura interior libre de su sala
	local roomsById = {}
	for _, room in rooms do
		roomsById[room.id] = room
	end
	for _, card in layout.cards do
		local room = roomsById[card.room]
		local slot = table.remove(room.freeSlots)
		if slot then
			card.x, card.z = slot.x, slot.z
		else
			local cx, cz = cellCenter(room.cells[1])
			card.x, card.z = cx + 4, cz + 4
		end
	end

	return layout, nil
end

-- Genera un layout válido. Devuelve layout (con layout.seed = semilla pedida y layout.attempt).
function LayoutGenerator.Generate(seed: number): any
	local lastReason = "?"
	for attempt = 0, ShipConfig.MaxAttempts - 1 do
		-- Reintentos en una secuencia separada (seed + attempt * 1000003): con "seed + n" la semilla 1000 reintentada
		-- daba el mismo mapa que la 1001 y semillas vecinas colisionaban.
		local layout, reason = tryGenerate(seed + attempt * 1000003)
		if layout then
			layout.seed = seed
			layout.attempt = attempt
			return layout
		end
		lastReason = reason or "?"
	end
	error(("ShipGen: ninguna generación válida para la semilla %d (último motivo: %s)"):format(seed, lastReason))
end

-- Versión que no lanza: devuelve layout o nil + motivo (para los tests)
function LayoutGenerator.TryGenerate(seed: number): (any?, string?)
	return tryGenerate(seed)
end

LayoutGenerator.Config = ShipConfig

return LayoutGenerator
