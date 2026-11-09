# Astronauta — GDD del rediseño (Infiltración en nave alienígena)

Documento de referencia del rediseño pedido por el usuario el 2026-11-09. Es la fuente de verdad para todas las etapas.

## Concepto
Terror, supervivencia e infiltración en una nave enorme tripulada por alienígenas humanoides. El jugador es un humano disfrazado de tripulante (uniforme + casco + identificación). El miedo viene de **que alguien descubra quién sos**, no solo de un monstruo.
Roblox Studio + Luau. **Se reutiliza la demo** (movimiento, linterna, iluminación/apagones, inventario/crafteo, escondites, partes de la IA). Primera persona. Estética low-poly PS1 modernizada: metal, tuberías, terminales, luz azul verdosa, rojo de emergencia, zonas oscuras.

**Prioridad: una versión pequeña, funcional y divertida antes de agrandar la nave.**

## Sistemas
1. **Mapa procedural (estilo DOORS):** sectores fijos en todas las partidas (dormitorios, laboratorios, comedor, seguridad, ingeniería, centro de mando, cápsulas de escape) con ubicación, conexiones, distribución interna y elementos variables. Módulos 3D reutilizables. Garantía de partida completable (sin salas inaccesibles ni rutas imposibles). Conexiones alternativas: ventilaciones, pasillos secundarios, accesos restringidos.
2. **Tripulación con rutinas:** científicos, técnicos, trabajadores, mantenimiento, guardias. Caminan, trabajan, descansan, interactúan, cambian de sector. Se adaptan al mapa generado.
3. **Infiltración:** uniforme, casco, identificaciones por nivel de acceso. Conductas sospechosas: zona restringida sin autorización, salir de una ventilación delante de alguien, correr, agacharse, linterna, conducta extraña. Varias soluciones por obstáculo (autorización / esperar a que abran / ventilación), cada una con riesgo.
4. **Sospecha individual:** cada alien tiene su nivel. Estados: Normal → Desconfianza → Investigación → Descubrimiento. Sube al observar conductas extrañas, baja si dejás de llamar la atención. **La UI explica por qué sube** (notificación discreta + indicador + historial breve). Nunca descubrir al jugador sin que entienda qué hizo mal.
5. **Comunicación y seguridad:** quien descubre al intruso no ataca: va a una terminal / comunicador / guardia cercano. Los guardias reciben el incidente y van a investigar con **última posición conocida, pistas y testimonios** (sin conocimiento mágico). Sospecha individual pero información compartible.
6. **Alerta y dificultad:** ser descubierto no es perder. Alerta confirmada → búsqueda activa, más controles de identificación, sectores bloqueados. Al escapar de la búsqueda la nave **no vuelve del todo a la normalidad** (controles reforzados persistentes). Siempre existe posibilidad de ganar.
7. **Recuperación de identidad:** identidad comprometida → conseguir otro uniforme + nueva ID. Difícil, no elimina la alerta general, y quienes te descubrieron pueden reconocerte.
8. **Objetivos variables y escape:** obtener IDs, reparar sistemas, componentes, terminales, preparar cápsula. Cambian entre partidas (reparar cápsula / desbloquear hangar / código de lanzamiento). Misterio de por qué el protagonista está en la nave (registros a descubrir).

## Etapas
1. Generación procedural (prototipo con módulos simples; mapa distinto por partida; todo accesible; rutas alternativas).
2. Tripulación alienígena (rutinas, desplazamientos, actividades).
3. Infiltración y sospecha (uniformes, IDs, detección, sospecha individual, notificaciones explicativas).
4. Seguridad (comunicación, investigación, niveles de alerta, consecuencias).
5. Objetivos y escape (objetivos variables, rutas de escape, recuperación de identidad).
6. Visual y ambientación (modelos, animaciones, luz, sonido, decoración low-poly retro).
7. Pruebas y optimización (dificultad, IA, rendimiento, duración).

## Reparto de propiedad de archivos (para no pisarse)
- **Claude:** `src/server/**` (incluye `Main.server.luau`, `ShipGen/`, servicios), `src/shared/**` salvo lo indicado abajo.
- **Lead (Antigravity):** `default.project.json`, `src/client/FirstPersonController.luau`, `src/client/Main.client.luau`, `Docs/`.
- Cualquier otro archivo de cliente: avisar en el buzón antes de tocarlo.
- Guardar siempre en **UTF-8 sin BOM**.
