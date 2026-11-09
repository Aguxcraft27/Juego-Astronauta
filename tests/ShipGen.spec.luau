-- Test headless del generador de la nave (Etapa S1).
-- Ejecutar desde la raíz del proyecto:   luau tests/ShipGen.spec.luau
-- Genera N semillas, valida cada layout de forma INDEPENDIENTE al generador y reporta:
-- fallos, reintentos, tiempo medio, distribución de sectores, salas, ciclos, ventilaciones.

local LayoutGenerator = require("../src/shared/ShipGen/LayoutGenerator")
local Validator = require("../src/shared/ShipGen/Validator")
local Config = LayoutGenerator.Config

local N = 500
local BASE_SEED = 1000

local failures = {}
local totalTime = 0
local maxTime = 0
local attemptsHist = {}
local sectorCount = {}
local roomTotal, cycleTotal, ventTotal, largeTotal = 0, 0, 0, 0
local roomMin, roomMax = math.huge, 0

local function fail(seed, msg)
	table.insert(failures, ("semilla %d: %s"):format(seed, msg))
end

-- Comprobaciones independientes del Validator del generador
local function check(seed, layout)
	-- 1. Celdas sin solapes y salas 1x1 / 2x1
	local occ = {}
	for _, room in layout.rooms do
		local n = #room.cells
		if n ~= room.w * room.h or not (n == 1 or n == 2) then
			return fail(seed, "tamaño de sala inválido " .. room.id)
		end
		for _, c in room.cells do
			local k = c[1] .. "," .. c[2]
			if occ[k] then
				return fail(seed, "solape en " .. k)
			end
			occ[k] = room.id
		end
	end
	-- 2. Cada arista une salas realmente vecinas por la celda/dirección indicada
	local d = { E = { 1, 0 }, W = { -1, 0 }, S = { 0, 1 }, N = { 0, -1 } }
	for _, e in layout.edges do
		local v = d[e.dir]
		if occ[e.cell[1] .. "," .. e.cell[2]] ~= e.a or occ[(e.cell[1] + v[1]) .. "," .. (e.cell[2] + v[2])] ~= e.b then
			return fail(seed, "arista " .. e.id .. " no coincide con la geometría")
		end
		if e.type == "Pasillo" and e.level > 0 then
			return fail(seed, "pasillo abierto hacia sala restringida")
		end
	end
	-- 3. Completabilidad paso a paso con las tarjetas colocadas (sin ventilaciones)
	local level = 0
	local byLevel = {}
	for _, card in layout.cards do
		byLevel[card.level] = card
	end
	for k = 1, 3 do
		local reach = Validator.Reach(layout, level)
		local card = byLevel[k]
		if not card or reach[card.room] == nil then
			return fail(seed, "tarjeta " .. k .. " inalcanzable con nivel " .. level)
		end
		level = k
	end
	local reach = Validator.Reach(layout, 3)
	local present = {}
	for _, room in layout.rooms do
		if reach[room.id] == nil then
			return fail(seed, "sala inaccesible " .. room.sector)
		end
		present[room.sector] = true
	end
	for _, s in Config.RequiredSectors do
		if not present[s] then
			return fail(seed, "falta " .. s)
		end
	end
	-- 4. Restringidas con >= 2 accesos; ciclos; ventilaciones
	local incident = {}
	local cycles, vents = 0, 0
	for _, e in layout.edges do
		incident[e.a] = (incident[e.a] or 0) + 1
		incident[e.b] = (incident[e.b] or 0) + 1
		if e.extra then
			cycles += 1
		end
		if e.type == "Ventilacion" then
			vents += 1
		end
	end
	-- aristas extra que NO son ventilación crean ciclos transitables; las ventilaciones también son ciclos
	for _, room in layout.rooms do
		if room.level > 0 and (incident[room.id] or 0) < 2 then
			return fail(seed, "restringida con 1 acceso: " .. room.sector)
		end
	end
	if cycles < 2 then
		return fail(seed, "menos de 2 ciclos")
	end
	if vents < Config.VentsMin or vents > Config.VentsMax then
		return fail(seed, "ventilaciones fuera de rango: " .. vents)
	end
	-- 5. Puntos semánticos: al menos un PatrolPoint por sala
	local patrol = {}
	for _, p in layout.points do
		if p.kind == "PatrolPoint" then
			patrol[p.room] = true
		end
	end
	for _, room in layout.rooms do
		if not patrol[room.id] then
			return fail(seed, "sala sin PatrolPoint")
		end
	end

	-- estadísticas
	roomTotal += #layout.rooms
	roomMin = math.min(roomMin, #layout.rooms)
	roomMax = math.max(roomMax, #layout.rooms)
	cycleTotal += cycles
	ventTotal += vents
	for _, room in layout.rooms do
		sectorCount[room.sector] = (sectorCount[room.sector] or 0) + 1
		if #room.cells == 2 then
			largeTotal += 1
		end
	end
	return true
end

-- Determinismo: misma semilla -> mismo layout
local function signature(layout)
	local parts = {}
	for _, r in layout.rooms do
		table.insert(parts, r.sector .. r.x .. "," .. r.z .. r.w .. r.h)
	end
	for _, e in layout.edges do
		table.insert(parts, e.type .. e.a .. "-" .. e.b)
	end
	return table.concat(parts, ";")
end

local distinct = {}
local distinctCount = 0
for i = 0, N - 1 do
	local seed = BASE_SEED + i
	local t0 = os.clock()
	local ok, layoutOrErr = pcall(LayoutGenerator.Generate, seed)
	local dt = os.clock() - t0
	totalTime += dt
	maxTime = math.max(maxTime, dt)
	if not ok then
		fail(seed, tostring(layoutOrErr))
	else
		local layout = layoutOrErr
		attemptsHist[layout.attempt] = (attemptsHist[layout.attempt] or 0) + 1
		check(seed, layout)
		local sig = signature(layout)
		if not distinct[sig] then
			distinct[sig] = true
			distinctCount += 1
		end
		if i < 20 and signature(LayoutGenerator.Generate(seed)) ~= sig then
			fail(seed, "no determinista")
		end
	end
end

print(("=== ShipGen: %d semillas (%d..%d) ==="):format(N, BASE_SEED, BASE_SEED + N - 1))
print(("Fallos de validación: %d"):format(#failures))
for i = 1, math.min(10, #failures) do
	print("  - " .. failures[i])
end
print(("Tiempo medio: %.2f ms  (máx %.2f ms)"):format(totalTime / N * 1000, maxTime * 1000))
print(("Layouts distintos: %d / %d"):format(distinctCount, N))
local ok = N - #failures
if ok > 0 then
	print(("Salas por mapa: media %.1f (min %d, máx %d); salas 2x1: %.1f por mapa"):format(
		roomTotal / ok, roomMin, roomMax, largeTotal / ok))
	print(("Aristas extra (ciclos) por mapa: %.2f · ventilaciones por mapa: %.2f"):format(cycleTotal / ok, ventTotal / ok))
end
local attemptsLine = {}
for a = 0, 49 do
	if attemptsHist[a] then
		table.insert(attemptsLine, ("%d:%d"):format(a, attemptsHist[a]))
	end
end
print("Reintentos necesarios (reintento:mapas): " .. table.concat(attemptsLine, "  "))
print("Distribución de sectores (salas totales):")
local names = {}
for s in sectorCount do
	table.insert(names, s)
end
table.sort(names)
for _, s in names do
	print(("  %-12s %5d  (%.2f por mapa)"):format(s, sectorCount[s], sectorCount[s] / math.max(ok, 1)))
end
if #failures > 0 then
	error("ShipGen: hay fallos")
end
