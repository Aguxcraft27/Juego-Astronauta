# PROYECTO ASTRONAUTA — MANUAL DE ONBOARDING PARA LA IA
*(Documento de transferencia técnica y contexto operativo)*

> **Para la IA asistente que lea este documento:**  
> Estás asumiendo el rol de desarrollador/a técnico y copiloto de programación para el videojuego **Astronauta**. Lee este documento completo antes de generar cualquier código o realizar modificaciones en el repositorio. Aquí encontrarás todo el contexto de diseño, arquitectura, herramientas, estado actual y siguientes pasos.

---

## 1. Visión y Concepto del Videojuego

* **Género:** Terror de supervivencia, sigilo táctico e infiltración en el espacio.
* **Plataforma y Motor:** **Roblox Studio**, programado en **Luau**.
* **Estética:** Retro Low-Poly PS1 / Sci-Fi Analógico de los 90s (inspirado en *Signalis*, *Iron Lung*, *Mouthwashing* y naves soviéticas retro-futuristas).
* **Mecánica Central (El Pivote):**  
  No es un juego de escapar de un monstruo genérico. El jugador es un humano que debe **infiltrarse en una enorme nave alienígena haciéndose pasar por un miembro de la tripulación** (usando un traje y casco alienígena de cosmonauta). El miedo proviene de la tensión constante de que **alguien de la tripulación descubra quién eres en realidad**.
* **Inspiraciones:**
  * **DOORS (Roblox):** Generación procedural de salas modulares, iluminación tenue cálida con lámparas de techo, eventos dinámicos de parpadeo y cortes de energía/apagones.
  * **Alien: Isolation / Amnesia:** Algoritmos de sigilo predecibles, justos y telegrafiados, armarios seguros, tensión acústica y recursos limitados.

---

## 2. Stack Tecnológico y Flujo de Trabajo

* **Lenguaje:** **Luau** (tipado estricto donde sea posible).
* **Gestor de Proyecto:** **Rojo** (`default.project.json`).
* **Binarios Luau (en local):**
  * `luau-compile.exe`: Compila archivos Luau y detecta errores de sintaxis antes de empaquetar.
  * `luau.exe`: Intérprete headless para ejecutar tests unitarios sin abrir Roblox Studio.
* **Construcción del Place:**  
  * Ejecutar el script `Scripts\BuildRobloxPlace.bat` (o `rojo build default.project.json -o Astronauta.rbxl`).
  * Genera el archivo final [`Astronauta.rbxl`](file:///c:/Users/bosco/Desktop/Proyectos%20de%20Claude/Juego%20astronauta/Astronauta.rbxl) listo para abrir y jugar en Roblox Studio.

---

## 3. Estructura del Repositorio

```text
├── .gitignore
├── default.project.json       # Configuración del proyecto Rojo y mapping a Roblox
├── Astronauta.rbxl            # Archivo binario ejecutable en Roblox Studio
├── AI_ONBOARDING.md           # Este manual maestro de contexto para la IA
├── CLAUDE.md                  # Reglas rápidas de codificación para agentes AI
├── Docs/
│   └── GDD_Infiltracion.md    # Documento de Diseño del Juego (GDD oficial)
├── Referencias_Estilo/        # Imágenes de referencia estética (cosmonauta soviético, CRT, etc.)
├── Scripts/
│   └── BuildRobloxPlace.bat   # Script para construir el place Astronauta.rbxl
├── tests/
│   └── ShipGen.spec.luau      # Suite de tests headless (valida algoritmos en CLI)
├── src/
│   ├── shared/                # Módulos compartidos (Cliente y Servidor)
│   │   ├── Types.luau         # Enums, estados, tags de CollectionService, remotes
│   │   ├── AlienConfig.luau   # Constantes de balanceo (tasas, distancias, tiempos)
│   │   ├── CraftingConfig.luau# Recetas de crafteo y recursos
│   │   └── ShipGen/           # Algoritmo puro de generación procedural (sin APIs Roblox)
│   │       ├── Rng.luau       # Generador de números pseudoaleatorios (xorshift32)
│   │       ├── ShipConfig.luau# Definición de sectores, celdas y reglas de generación
│   │       ├── LayoutGenerator.luau # Algoritmo generador de grafo y habitaciones
│   │       └── Validator.luau # Validador llave-cerradura (garantía de completabilidad)
│   ├── server/                # Scripts del Servidor (ServerScriptService)
│   │   ├── Main.server.luau   # Punto de entrada del servidor
│   │   ├── StationAlarmService.luau # Manejo de Alerta Roja, sirenas y luces
│   │   ├── PowerGridService.luau    # Lluvia de meteoritos, parpadeos y apagón
│   │   ├── PlayerStateService.luau  # Traje del cosmonauta, linterna, modos de paso
│   │   ├── HidingSpotService.luau   # Sistema de armarios y taquillas
│   │   ├── VacuumService.luau       # Zonas sin oxígeno / despresurización
│   │   ├── CraftingService.luau     # Crafteo en tiempo real
│   │   ├── GadgetService.luau       # Minas PEM, bombas de humo, botiquines
│   │   ├── BloodTrailService.luau   # Rastro de sangre si HP < 40
│   │   ├── StationDecor.luau        # Monitores CRT, muebles retro, ambientación
│   │   └── ShipGen/                 # Ensamblador 3D en Workspace de Roblox
│   │       ├── RoomLibrary.luau     # Generación de paredes, luces, props por sector
│   │       └── ShipBuilder.luau     # Instanciador en Workspace.Ship y puertas
│   └── client/                # Scripts del Cliente (StarterPlayerScripts)
│       ├── Main.client.luau         # Punto de entrada del cliente
│       ├── FirstPersonController.luau # Cámara bloqueada en 1ra persona + headbob
│       ├── AstronautController.luau # Movimiento (Walk/Run/Crouch), linterna 3D, HUD
│       ├── AmbienceController.luau  # Sonidos de respiración, ventilación, reactor
│       ├── MotionTrackerController.luau # Radar/Rastreador de movimiento analógico
│       ├── InventoryUI.luau         # Interfaz de crafteo y uso rápido de gadgets
│       ├── MissionUI.luau           # Indicador de objetivos y avisos
│       └── PSXPostProcessing.luau   # Filtro retro PS1 procedural
└── chat_claude/               # Historial de decisiones de diseño y coordinación técnica
    ├── buzon_claude.md        # Directivas de diseño emitidas por el Lead
    └── buzon_lead.md          # Reportes técnicos de entrega
```

---

## 4. Estado Actual del Proyecto (Dónde estamos)

### Lo que ya está 100% implementado y probado:
1. **Generación Procedural de Nave (Etapa 1 Completada):**
   * Algoritmo de árbol expansivo + ciclos con salas de 1x1 y 2x1 celdas de 40 studs.
   * Sectores presentes en cada partida: *Dormitorios (Spawn), Comedor, Laboratorio, Seguridad, Ingeniería, Mando, Cápsulas de escape, Almacenes y Pasillos*.
   * Validador matemático (*key-lock* BFS) verificado con **500 semillas consecutivas (100% éxito, 0 errores)**: garantiza que todas las salas obligatorias sean alcanzables, que las tarjetas de acceso se coloquen antes de sus puertas y que existan conductos de ventilación alternativos para flanquear zonas restringidas.
2. **Iluminación e Inmersión:**
   * Iluminación cálida y tenue estilo *DOORS* (`Ambient (70, 64, 58)`, brillo 1.0, lámparas de techo).
   * Evento dinámico `PowerGridService`: impactos de meteoritos hacen parpadear las luces hasta provocar un apagón total durante 16s donde la linterna es indispensable.
3. **Control en Primera Persona y Linterna 3D:**
   * Cámara bloqueada en primera persona con balanceo suave de cabeza y ocultamiento del casco en cliente para evitar solapamientos visuales.
   * Linterna 3D (`SpotLight`) que sigue en tiempo real (`RenderStepped`) el ángulo exacto de la mirada del jugador.
4. **Supervivencia y Gadgets:**
   * Armarios interactivos con `[E]` que ofrecen refugio seguro.
   * Sistema de crafteo en tiempo real (`Tab` o `I`) de minas PEM, bombas de humo y botiquines.
   * Rastro de sangre si la salud baja de 40 HP.

---

## 5. Hoja de Ruta Maestra (Roadmap por Etapas)

El desarrollo del rediseño está planificado en 7 etapas progresivas:

* **[x] Etapa 1: Generación Procedural** (Completada).
* **[→] Etapa 2: Tripulación Alienígena y Rutinas** (**EN PROCESO / SIGUIENTE PASO INMEDIATO**):
  * Crear modelos humanoides para la tripulación (Científicos, Técnicos, Trabajadores y Guardias) con skins low-poly diferenciadas.
  * Spawn dinámico basado en las salas generadas (`ShipPoint`: WorkStation, Bed, Seat, Terminal, PatrolPoint).
  * Agenda de rutinas: trabajar, descansar en dormitorios, comer en el comedor, patrullar sectores y abrir puertas según su `AccessLevel`.
  * En esta etapa los tripulantes son **neutrales** (realizan sus vidas sin atacar).
* **[ ] Etapa 3: Infiltración y Sospecha Individual**:
  * Sistema de uniforme y casco: si te lo quitas o actúas de forma extraña, sube la sospecha.
  * Sospecha individual por tripulante (Normal → Desconfianza → Investigación → Descubrimiento).
  * **Regla de Oro:** La interfaz debe explicar siempre **por qué** subió la sospecha (notificación breve + historial).
* **[ ] Etapa 4: Seguridad y Alerta**:
  * Quien descubre al jugador no ataca de inmediato: corre a una terminal o avisa a un guardia.
  * Los guardias buscan basándose en última posición conocida y pistas (sin teletransportes mágicos).
  * Si la alarma se activa, aumenta la dificultad y los controles, pero el jugador aún puede esconderse y ganar.
* **[ ] Etapa 5: Objetivos Variables y Escape**:
  * Tareas variables por partida: reparar cápsula, piratear terminales, conseguir componentes o códigos de lanzamiento.
  * Mecánica de recuperación de identidad comprometida (conseguir nuevo uniforme/ID).
* **[ ] Etapa 6: Arte y Atmósfera Retro PS1**:
  * Pulido de modelos low-poly, texturas pixeladas, shaders y animaciones.
* **[ ] Etapa 7: Balance y Pruebas**:
  * Ajuste de curvas de dificultad, tiempos de respuesta y pruebas de rendimiento.

---

## 6. Reglas Técnicas y Directrices Críticas para la IA

1. **Codificación UTF-8 SIN BOM:**
   * **¡Cuidado con PowerShell!** En Windows, comandos como `Set-Content -Encoding utf8` guardan con BOM (`U+FEFF`), lo que hace fallar a `luau-compile`. Guarda siempre en UTF-8 puro sin BOM.
2. **Autoridad en el Servidor:**
   * La lógica de IA, inventario, apertura de puertas, verificación de tarjetas y niveles de sospecha residen en el **Servidor** (`src/server/`).
   * El cliente (`src/client/`) solo maneja inputs, efectos de cámara, predicciones visuales y renderizado del HUD.
3. **Presupuesto de Rendimiento:**
   * La máquina objetivo corre gráficos integrados (ej. Radeon 610M). Mantén el conteo total de partes por mapa por debajo de **6.000 partes** y no actives `CastShadow` en luces de relleno o focos pequeños.
4. **Verificación Continua:**
   * Antes de dar por finalizada una tarea, corre:
     ```powershell
     # Compilar place
     Scripts\BuildRobloxPlace.bat
     # Ejecutar tests headless
     C:\Users\bosco\AppData\Local\Temp\claude\luau\bin\luau.exe tests/ShipGen.spec.luau
     ```

---

## 7. Instrucciones para Continuar el Desarrollo

Si estás continuando el proyecto a partir de este punto:
1. Revisa [`Docs/GDD_Infiltracion.md`](file:///c:/Users/bosco/Desktop/Proyectos%20de%20Claude/Juego%20astronauta/Docs/GDD_Infiltracion.md) para cualquier detalle de diseño conceptual.
2. Tu prioridad inmediata es la **Etapa 2**: Crear el servicio de tripulación (`src/server/Crew/`), generar los tripulantes humanoides en las salas correspondientes y poner a funcionar sus rutinas cíclicas (trabajo, descanso, patrulla y apertura de puertas autorizadas).
3. Asegúrate de ejecutar `Scripts\BuildRobloxPlace.bat` tras cada módulo para garantizar que `Astronauta.rbxl` se construya sin errores.
