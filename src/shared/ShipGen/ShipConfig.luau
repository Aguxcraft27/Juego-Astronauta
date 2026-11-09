--!strict
-- Configuración del generador de la nave (Etapa S1). Puro: sin APIs de Roblox.

local ShipConfig = {}

-- Sectores obligatorios (aparecen en TODAS las partidas) y de relleno
ShipConfig.RequiredSectors = { "Dormitorios", "Laboratorio", "Comedor", "Seguridad", "Ingenieria", "Mando", "Capsulas" }
ShipConfig.FillerSectors = { "Pasillo", "Almacen" }
ShipConfig.SpawnSector = "Dormitorios"
ShipConfig.FinalSector = "Capsulas" -- se coloca el último (lo más profundo posible)

-- Niveles de acceso: 0 público, 1 técnico, 2 científico, 3 seguridad/mando
ShipConfig.AccessLevel = {
	Dormitorios = 0,
	Laboratorio = 2,
	Comedor = 0,
	Seguridad = 3,
	Ingenieria = 1,
	Mando = 3,
	Capsulas = 3,
	Pasillo = 0,
	Almacen = 0,
}

-- Salas "importantes" que deben tener una ventilación que salte su puerta
ShipConfig.VentBypassSectors = { "Laboratorio", "Seguridad", "Mando" }

-- Probabilidad de que una sala ocupe 2x1 celdas (por sector)
ShipConfig.LargeRoomChance = {
	Dormitorios = 0.6,
	Laboratorio = 0.5,
	Comedor = 0.7,
	Seguridad = 0.3,
	Ingenieria = 0.6,
	Mando = 0.5,
	Capsulas = 0.5,
	Pasillo = 0.5,
	Almacen = 0.2,
}

-- Geometría
ShipConfig.CellSize = 40 -- studs por celda
ShipConfig.WallHeight = 14
ShipConfig.MaxCoord = 6 -- la grilla va de -MaxCoord a +MaxCoord en X y Z (13x13 celdas)

-- Tamaño del prototipo
ShipConfig.RoomCountMin = 14
ShipConfig.RoomCountMax = 18

-- Conexiones
ShipConfig.ExtraEdgesMin = 2 -- aristas extra que crean ciclos
ShipConfig.ExtraEdgesMax = 4
ShipConfig.VentsMin = 2
ShipConfig.VentsMax = 4
ShipConfig.PublicCorridorChance = 0.4 -- arista entre salas públicas: Pasillo (abierto) en vez de Puerta

ShipConfig.MaxAttempts = 50 -- reintentos (seed + n) si una generación no valida

-- Puntos semánticos por sector (para la tripulación en S2). Se colocan en "ranuras" de cada celda:
-- 4 esquinas (junto a las paredes, lejos de los huecos de puerta) y 4 interiores.
ShipConfig.PointKinds = { "WorkStation", "Bed", "Seat", "Terminal", "PatrolPoint", "HidingSpot", "VentExit" }

ShipConfig.RoomRecipes = {
	Dormitorios = { Bed = 3, Seat = 1, HidingSpot = 1 },
	Laboratorio = { WorkStation = 2, Terminal = 1, HidingSpot = 1 },
	Comedor = { Seat = 4, WorkStation = 1 },
	Seguridad = { Terminal = 2, Seat = 1, HidingSpot = 1 },
	Ingenieria = { WorkStation = 2, Terminal = 1, HidingSpot = 1 },
	Mando = { Terminal = 3, Seat = 1 },
	Capsulas = { WorkStation = 2, Terminal = 1 },
	Pasillo = { HidingSpot = 1 },
	Almacen = { WorkStation = 1, HidingSpot = 1 },
}
-- Cada celda tiene además un PatrolPoint en su centro.

-- Tipos de punto que van en ranura de esquina (junto a pared) o interior
ShipConfig.CornerKinds = { Bed = true, HidingSpot = true, WorkStation = true, Terminal = true }

return ShipConfig
