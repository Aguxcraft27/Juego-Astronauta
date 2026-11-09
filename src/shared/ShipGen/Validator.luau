--!nonstrict
-- Garantía de completabilidad (modelo llave-cerradura) para ShipGen. Puro: sin APIs de Roblox.
--
-- Reglas:
--   * Se puede atravesar: Pasillo siempre; Puerta si su AccessLevel <= nivel de tarjeta que tienes.
--     Las ventilaciones NO cuentan para la garantía: la partida debe poder completarse sin ellas
--     (son rutas alternativas con riesgo, no la única solución).
--   * La tarjeta de nivel k se coloca en una sala de nivel < k alcanzable con nivel k-1.
--   * Con nivel 3 se alcanzan TODAS las salas (incluidas las obligatorias y Capsulas).
--   * Cada sala restringida (nivel > 0) tiene al menos 2 accesos (aristas de cualquier tipo).
--   * Hay al menos ExtraEdgesMin ciclos (aristas fuera del árbol de crecimiento).

local Validator = {}

type Room = { [string]: any }
type Edge = { [string]: any }
type Layout = { [string]: any }

local function adjacency(layout: Layout): { [number]: { Edge } }
	local adj: { [number]: { Edge } } = {}
	for _, room in layout.rooms do
		adj[room.id] = {}
	end
	for _, edge in layout.edges do
		table.insert(adj[edge.a], edge)
		table.insert(adj[edge.b], edge)
	end
	return adj
end

local function passable(edge: Edge, level: number): boolean
	if edge.type == "Pasillo" then
		return true
	elseif edge.type == "Puerta" then
		return edge.level <= level
	end
	return false -- Ventilacion: no cuenta para la garantía
end

-- BFS desde el spawn con un nivel de tarjeta. Devuelve { [roomId] = profundidad }.
function Validator.Reach(layout: Layout, level: number, adj: { [number]: { Edge } }?): { [number]: number }
	local graph = adj or adjacency(layout)
	local depth: { [number]: number } = { [layout.spawnRoom] = 0 }
	local queue = { layout.spawnRoom }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, edge in graph[current] do
			if passable(edge, level) then
				local other = if edge.a == current then edge.b else edge.a
				if depth[other] == nil then
					depth[other] = depth[current] + 1
					table.insert(queue, other)
				end
			end
		end
	end
	return depth
end

-- Coloca las tarjetas de acceso (niveles 1..3) y valida la partida. Devuelve ok, motivo.
function Validator.PlaceCardsAndValidate(layout: Layout, rng: any, config: any): (boolean, string?)
	local adj = adjacency(layout)
	local roomsById: { [number]: Room } = {}
	for _, room in layout.rooms do
		roomsById[room.id] = room
	end

	layout.cards = {}
	local used: { [number]: boolean } = {}
	for k = 1, 3 do
		local reach = Validator.Reach(layout, k - 1, adj)
		-- Candidatas: salas de nivel < k alcanzables, sin otra tarjeta; preferir las más profundas
		local candidates = {}
		local maxDepth = -1
		for id, d in reach do
			local room = roomsById[id]
			if room.level < k and not used[id] then
				table.insert(candidates, { id = id, depth = d })
				maxDepth = math.max(maxDepth, d)
			end
		end
		if #candidates == 0 then
			return false, ("sin sala para la tarjeta de nivel %d"):format(k)
		end
		-- Evitar el spawn si hay alternativa
		local filtered = {}
		for _, c in candidates do
			if c.id ~= layout.spawnRoom then
				table.insert(filtered, c)
			end
		end
		if #filtered > 0 then
			candidates = filtered
		end
		-- Elegir entre la mitad más profunda
		table.sort(candidates, function(a, b)
			if a.depth ~= b.depth then
				return a.depth > b.depth
			end
			return a.id < b.id
		end)
		local top = math.max(1, math.ceil(#candidates / 2))
		local chosen = candidates[rng:NextInt(1, top)]
		used[chosen.id] = true
		table.insert(layout.cards, { level = k, room = chosen.id })
	end

	-- Todo alcanzable con nivel 3
	local full = Validator.Reach(layout, 3, adj)
	for _, room in layout.rooms do
		if full[room.id] == nil then
			return false, ("sala %d (%s) inaccesible"):format(room.id, room.sector)
		end
	end
	local present: { [string]: boolean } = {}
	for _, room in layout.rooms do
		present[room.sector] = true
	end
	for _, sector in config.RequiredSectors do
		if not present[sector] then
			return false, "falta el sector " .. sector
		end
	end

	-- Cada restringida con >= 2 accesos
	for _, room in layout.rooms do
		if room.level > 0 and #adj[room.id] < 2 then
			return false, ("sala restringida %d (%s) con un solo acceso"):format(room.id, room.sector)
		end
	end

	-- Ciclos
	local extra = 0
	for _, edge in layout.edges do
		if edge.extra then
			extra += 1
		end
	end
	if extra < config.ExtraEdgesMin then
		return false, "pocos ciclos"
	end

	-- Ventilaciones que saltan las puertas importantes
	for _, sector in config.VentBypassSectors do
		for _, room in layout.rooms do
			if room.sector == sector then
				local hasVent = false
				for _, edge in adj[room.id] do
					if edge.type == "Ventilacion" then
						hasVent = true
					end
				end
				if not hasVent then
					return false, "sin ventilación en " .. sector
				end
			end
		end
	end

	-- Profundidad de cada sala (con nivel 3) para S2 / depuración
	for _, room in layout.rooms do
		room.depth = full[room.id]
	end
	return true, nil
end

return Validator
