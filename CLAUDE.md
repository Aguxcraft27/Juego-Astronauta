# GUÍA RÁPIDA DE DESARROLLO — CLAUDE / ASISTENTE IA

Lee siempre `AI_ONBOARDING.md` para el contexto completo de diseño y arquitectura.

## Comandos Principales
- **Construir el juego para Roblox Studio:** `Scripts\BuildRobloxPlace.bat` (genera `Astronauta.rbxl`).
- **Ejecutar tests headless en CLI:** `C:\Users\bosco\AppData\Local\Temp\claude\luau\bin\luau.exe tests/ShipGen.spec.luau`
- **Comprobar sintaxis Luau:** `C:\Users\bosco\AppData\Local\Temp\claude\luau\bin\luau-compile.exe <archivo.luau>`

## Reglas Obligatorias de Código
1. **UTF-8 sin BOM:** Nunca guardes archivos con BOM (`U+FEFF`).
2. **Autoridad en el Servidor:** Todo lo que afecta gameplay (inventario, IA, puertas, sospecha, estados) se valida y ejecuta en `src/server/`.
3. **Optimización Low-Poly:** No exceder 6.000 partes por mapa. Evitar sombras en luces secundarias.
4. **Sincronización:** El mapeo de carpetas con Roblox se gestiona a través de `default.project.json` (Rojo).
