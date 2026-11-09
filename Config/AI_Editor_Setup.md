# Configuración de la IA del Alien en el Editor (UE 5.4)

Guía para montar en el editor los assets que no se pueden crear desde C++: el Blackboard, el Behavior Tree, los Blueprints y el nivel. Los nombres de las claves tienen que coincidir **exactamente** con `AlienBBKeys` en `Source/Astronauta/AI/AlienAITypes.h`.

---

## 1. Blackboard `BB_Alien`

Ruta sugerida: `Content/AI/BB_Alien`.

| Clave | Tipo | Configuración | Valor por defecto | Quién la escribe |
|---|---|---|---|---|
| `AlienState` | Enum | Enum Name = `EAlienAIState` | `Patrullar` | `AAlienAIController::SetAlienState` |
| `TargetActor` | Object | Base Class = `Actor` | vacío | Controlador: jugador, cadáver o `AHidingSpot` |
| `InvestigationLocation` | Vector | — | vacío (no asignado) | Controlador: origen del estímulo o último punto visto |
| `TargetAlarmConsole` | Object | Base Class = `AlarmConsole` | vacío | Controlador (transición 3) |
| `SuspicionMeter` | Float | — | 0.0 | Controlador (lectura y depuración) |
| `bPlayerIdentified` | Bool | — | false | Controlador |
| `bIsAlarmTriggered` | Bool | — | false | Controlador |
| `bHasSeenCorpse` | Bool | — | false | Controlador |
| `PatrolLocation` | Vector | — | vacío | `Find Patrol Point` / `Find Chokepoint` |

> El BT **solo lee** estas claves (salvo `PatrolLocation`). Todas las transiciones de estado las decide el controlador en C++; el BT reacciona con decoradores.

---

## 2. Behavior Tree `BT_Alien`

Blackboard Asset = `BB_Alien`.

```
ROOT
└── Selector "Estado"                         [Service: Update Suspicion (Interval 0.1, Random Deviation 0)]
    │
    ├── (1) Selector "Alerta Roja"            [Decorator Blackboard: AlienState == AlertaRoja | Observer Aborts: Both]
    │   ├── Sequence "Cacería / forzar escondite"
    │   │      [Decorator Blackboard: TargetActor Is Set | Notify: On Value Change | Observer Aborts: Both]
    │   │   └── MoveTo  (Blackboard Key: TargetActor, Acceptable Radius 50,
    │   │                Reach Test Includes Agent Radius = false, Reach Test Includes Goal Radius = false,
    │   │                Observe Blackboard Value = true)
    │   ├── Sequence "Registrar último punto"
    │   │      [Decorator Blackboard: InvestigationLocation Is Set | Notify: On Value Change | Observer Aborts: Self]
    │   │   ├── MoveTo  (InvestigationLocation, Acceptable Radius 80, Observe Blackboard Value = true)
    │   │   └── Search Area  (Search Duration 3, Look Interval 1)
    │   └── Sequence "Cerco en chokepoints"
    │       ├── Find Chokepoint  (Nearest Candidates 3)
    │       ├── MoveTo  (PatrolLocation, Acceptable Radius 100)
    │       ├── Inspect Hiding Spot  (Chance 0.2, Search Radius 500, Inspect Duration 3)
    │       └── Wait  (2.0 s, Random Deviation 1.0)
    │
    ├── (2) Sequence "Correr hacia alarma"     [Decorator Blackboard: AlienState == CorrerHaciaAlarma | Observer Aborts: Both]
    │   ├── MoveTo  (TargetAlarmConsole, Acceptable Radius 100)
    │   └── Trigger Alarm Console
    │
    ├── (3) Sequence "Investigar"             [Decorator Blackboard: AlienState == Investigar | Observer Aborts: Both]
    │      [Decorator Blackboard: InvestigationLocation Is Set | Notify: On Value Change | Observer Aborts: Self]
    │   ├── MoveTo  (InvestigationLocation, Acceptable Radius 80, Observe Blackboard Value = true)
    │   └── Search Area  (Search Duration 5, Look Interval 1.25)
    │
    └── (4) Sequence "Patrullar"              [Decorator Blackboard: AlienState == Patrullar | Observer Aborts: Both]
        ├── Find Patrol Point
        ├── MoveTo  (PatrolLocation, Acceptable Radius 50)
        └── Wait  (1.0 s, Random Deviation 0.5)
```

**Notas:**
- El orden del Selector raíz es la prioridad. Con `Observer Aborts: Both`, un cambio de `AlienState` corta la rama en curso en el siguiente tick.
- El decorador "On Value Change" de `InvestigationLocation` reinicia la búsqueda cuando llega un estímulo nuevo a más de 200 uu (umbral en `AlienAIController.cpp`).
- **Captura (CaptureRadius 100):** la comprueba el controlador en C++, no el BT. Por eso el `MoveTo` de cacería necesita un Acceptable Radius **menor** de 100 y los Reach Tests desactivados. Si no, el alien se queda parado antes de llegar.
- **Forzar escondite:** `TargetActor` apunta al `AHidingSpot`. La captura se dispara cuando el alien está a ≤100 uu (2D) del `ExitPoint` del escondite. Coloca el `ExitPoint` delante de la puerta y sobre el NavMesh.
- **Inspección:** si el jugador escondido hace ruido durante el olfateo (movimiento brusco vía `EmitNoise`, o el chisporroteo del camuflaje al agotarse dentro), el controlador pone el escondite en `TargetActor` y la rama "Cacería / forzar escondite" lo abre y captura.
- **Casillero visto fuera de AlertaRoja:** el alien de apoyo se queda en Investigar con `InvestigationLocation` = `ExitPoint` del casillero (vigila) hasta la alarma; entonces lo fuerza. El corredor lo ignora.
- **Linterna:** no necesita nodos. El servicio comprueba el haz en cada tick (cono + alcance + traza Visibility sin oclusores):
  - **De frente o lateral** (ángulo entre la mirada del alien y la linterna ≤ `FlashlightFrontalAngle` = 110°): sospecha a 100 y giro inmediato hacia la luz.
  - **Por la espalda** (> 110°): +40 una vez por exposición y, tras 0.5 s, Investigar el origen de la luz.
- **Pistas visuales:** los actores con tag `InvestigationClue` y `StimuliSource` de Sight (p. ej. una `VentGrate` rota) hacen que un alien en **Patrullar** pase a Investigar ese punto (una vez por alien y pista).
- **Conductos:** si un alien ve entrar al jugador, su `InvestigationLocation` pasa a la boca del conducto más cercana al alien (descartando la de entrada).
- **Corredor:** el `MoveTo` hacia la consola no tiene decoradores de distracción. El controlador ignora ruidos y cadáveres en `CorrerHaciaAlarma`.

### Nodos C++ disponibles
| Nodo | Tipo | Propiedades |
|---|---|---|
| Update Suspicion | Service | Interval 0.1 |
| Find Patrol Point | Task | — |
| Find Chokepoint | Task | Nearest Candidates (3) |
| Search Area | Task | Search Duration (5), Look Interval (1.25) |
| Trigger Alarm Console | Task | — (usa `AlarmInteractionRadius` y `ConsoleMontage` del pawn) |
| Inspect Hiding Spot | Task | Chance (0.2), Search Radius (500), Inspect Duration (3), Move Timeout (8). Siempre devuelve Succeeded. |

---

## 3. Blueprints

| Blueprint | Clase padre | Configurar |
|---|---|---|
| `BP_AlienController` | `AlienAIController` | `Behavior Tree Asset` = `BT_Alien`. Tuning en "Alien AI". |
| `BP_Alien` | `AlienCharacter` | `AI Controller Class` = `BP_AlienController`; malla, AnimBP, `Console Montage`, `Sniff Montage`; evento `OnInspectHidingSpot` (sonido de olfateo). En cada instancia del nivel: `Patrol Path`. |
| `BP_Astronauta` | `AstronautaCharacter` | Cámara, malla, Enhanced Input → `StartSprint`/`StopSprint`, `ToggleCrouch`, `ToggleCamouflage`, `InteractHidingSpot`, `ThrowDistraction`, `ToggleFlashlight`, `StartRemoveGrate` (pulsar) / `CancelRemoveGrate` (soltar), `KickGrate`. Re-anclar el componente `Flashlight` a la cámara si se quiere que apunte con la vista. `Throwable Class` = `BP_Lata`. |
| `BP_StationGameMode` | `StationGameMode` | `Default Pawn Class` = `BP_Astronauta`. Ponerlo en World Settings o en Project Settings → Maps & Modes. |
| `BP_Lata` | `ThrowableDistractionActor` | Static Mesh con colisión simple; masa ~0.5–2 kg. Evento `OnNoisyImpact` → sonido. |
| `BP_Locker` | `HidingSpot` | Mesh del casillero (debe **bloquear Visibility**); colocar `HidePoint` dentro y `ExitPoint` delante. Evento `OnForcedOpen`. |
| `BP_Consola` | `AlarmConsole` | Mesh; `InteractionPoint` delante del panel. |
| `BP_Puerta` | `StationDoor` | Mallas de paneles; evento `OnDoorVisualStateChanged` para animar. Ajustar `NavModifier → Failsafe Extent` al hueco. |
| `BP_LightingDirector` | `StationLightingDirector` | Uno por nivel. En la instancia: `Normal Lights` y `Emergency Lights` (arrastrar actores de luz), `Siren Sound` (en bucle), `Siren Attenuation`. Colocarlo donde deba sonar la sirena. |
| `BP_Cadaver` | `CorpseActor` | Skeletal mesh con Physics Asset. |
| `BP_Conducto` | `VentDuct` | `DuctVolume` cubriendo el interior del tramo; `Exits` (gizmo) **fuera** del conducto y sobre el NavMesh. La geometría del conducto debe ser más baja que la altura del agente de navegación del alien. |
| `BP_Rejilla` | `VentGrate` | Mesh en la boca del conducto; `InteractionVolume` delante. **El pivote del actor debe quedar unos 20 uu por delante de la pared** (la vista de la IA traza hasta el pivote cuando la rejilla rota se vuelve pista). Eventos `OnGrateRemoved` / `OnGrateBroken`. Barra de progreso con `GetRemovalProgress`. |

---

## 4. Checklist del nivel

### Navegación
- [ ] `NavMeshBoundsVolume` cubriendo toda la estación.
- [ ] Project Settings → Navigation Mesh → **Runtime Generation = Dynamic Modifiers Only** (ya está en `Config/DefaultEngine.ini`). Sin esto, las puertas bloqueadas no recortan el NavMesh.
- [ ] Pulsar `P` en el viewport: el NavMesh pasa por las puertas abiertas y llega a todas las consolas, chokepoints y `ExitPoint` de escondites.

### Actores obligatorios
- [ ] Al menos una `AlarmConsole` (sin ella, el alien que confirma al jugador no tiene adónde correr; queda un warning en el log).
- [ ] Una `PatrolPath` por alien, con sus puntos sobre el NavMesh, asignada en la instancia de `BP_Alien`.
- [ ] `ChokepointMarker` en pasillos y cruces clave. `Priority` más alta = preferido en empates de distancia.
- [ ] `HidingSpot`: el `HidePoint` debe quedar **dentro** de la colisión de la malla (así la vista del alien choca con el casillero y no ve al jugador).
- [ ] `VentDuct`: altura interior menor que la del alien (p. ej. 100 uu) y mayor que la cápsula agachada del jugador.
- [ ] `GameMode Override` = `BP_StationGameMode` (para que el GameState sea `StationGameState`).

### Colisión
| Objeto | Perfil | Requisito |
|---|---|---|
| Paredes, puertas cerradas, malla de `HidingSpot` | `BlockAll` | Bloquear **Visibility** (lo usa la vista de la IA). |
| Trigger de `StationDoor`, `InteractionVolume` de `HidingSpot` | `Trigger` | Overlap con `Pawn`. |
| `ThrowableDistractionActor` | `PhysicsActor` | `Simulation Generates Hit Events` = true (lo activa el C++). |
| `CorpseActor` | `Ragdoll` | — |
| Cápsula del jugador / alien | `Pawn` | — |

### Tags
- [ ] Cadáveres: tag `Corpse` (lo pone `ACorpseActor` automáticamente; si usas otro actor como cadáver, añade el tag a mano **y** un `AIPerceptionStimuliSource` registrado para Sight).

### Percepción
- [ ] El jugador no necesita `StimuliSource`: los Pawns se registran solos para Sight.
- [ ] Ruidos: pasos del jugador y `ThrowableDistractionActor` usan `ReportNoiseEvent`. No hace falta configurar nada más.
- [ ] Depurar con la tecla `'` (apóstrofo) → panel AI → Perception, y con `ShowDebug AI`.

---

## 5. Valores de ajuste (por defecto)

| Parámetro | Valor | Dónde |
|---|---|---|
| Sospecha corriendo / sin camuflaje | 35 / 20 por s (se suman) | Controller |
| Cadáver / ruido | +50 / +15 × Clamp(fuerza, 0.5, 2) | Controller |
| Enfriamiento | 12 por s | Controller |
| Umbral investigar / confirmar | 30 / 100 | Controller |
| Velocidad patrulla / investigar / carrera / alerta roja | 250 / 380 / 700 / 450 | Controller |
| Radio consola / captura | 150 / 100 | Controller |
| Cadáver movido | 300 uu | Controller |
| Vista (radio / pérdida / ángulo) | 2000 / 2300 / 50° | Controller (constructor) |
| Oído | 1500 uu | Controller (constructor) |
| Jugador andar / correr / agachado | 300 / 600 / 150 | AstronautaCharacter |
| Batería de camuflaje | 100, −20/s, +10/s | AstronautaCharacter |
| Lata: velocidad mín. / energía ref. / alcance base | 300 uu/s / 20 J / 1500 uu | ThrowableDistractionActor |
| Linterna: alcance / semiángulo | 1500 uu / 25° | AstronautaCharacter (`FlashlightRange`, `OuterConeAngle`) |
| Rejilla: retirada / ruido de rotura / alcance | 2 s / 1.8 / 1800 uu | VentGrate |
| Inspección: probabilidad / radio / duración | 20 % / 500 uu / 3 s | BTTask_InspectHidingSpot |
| Linterna: ángulo frontal / sospecha por la espalda / retardo | 110° / +40 / 0.5 s | Controller |
| Ruido del camuflaje agotado | 0.8 / 700 uu | AstronautaCharacter |
| Balizas: parpadeos por segundo / color | 1.5 / rojo (1, 0.05, 0.02) | StationLightingDirector |

---

## 6. Iluminación y audio de la estación (`AStationLightingDirector`)

| Elemento | Detalle |
|---|---|
| Modos | `EStationLightingMode::Normal` / `RedAlert` |
| Cambio automático | Escucha `AStationGameState::OnRedAlert` → `RedAlert`. Si el nivel carga con la alarma ya activa, arranca en `RedAlert`. |
| Normal | `NormalLights` visibles; `EmergencyLights` apagadas; sirena parada. |
| Alerta Roja | `NormalLights` apagadas; `EmergencyLights` con `EmergencyColor`, parpadeando a `BeaconBlinkRate`; `SirenAudio` (espacializado) en bucle. |
| API | `SetLightingMode(Mode)`, `GetLightingMode()` (BlueprintCallable / Pure) |
| Delegado | `OnLightingModeChanged(EStationLightingMode NewMode)` |
| Evento BP | `OnLightingModeApplied(NewMode)`: aquí se lanzan Level Sequences (Sequencer), post-proceso, niebla, etc. |

**Requisitos del nivel:**
- [ ] Las luces de `NormalLights` y `EmergencyLights` deben tener **Mobility = Movable** (o Stationary): las luces Static no se pueden apagar en juego.
- [ ] Si la iluminación se hornea (Lumen desactivado), las sombras de las luces apagadas quedan en el lightmap; con Lumen no hay problema.
- [ ] Para varias zonas de sirena, coloca varios `BP_LightingDirector`, cada uno con sus luces y su sonido.

---

## 7. Delegados para el HUD (UMG)

Enlazar en el `Event Construct` del widget (`Bind Event to …`):

| Delegado | Dónde | Firma | Cuándo se emite |
|---|---|---|---|
| `OnSuspicionUpdated` | `StationGameState` (`Get Game State` → Cast) | `(float NewValue)` 0-100 | Máximo de sospecha entre todos los aliens; solo al cambiar ≥ 0.5 o tocar 0 / 100. Valor actual: `GetMaxSuspicion()`. |
| `OnFlashlightToggled` | `AstronautaCharacter` | `(bool bIsOn)` | Al encender o apagar (y una vez en `BeginPlay`). |
| `OnCamouflageBatteryUpdated` | `AstronautaCharacter` | `(float Percent)` 0-1 | Cuando cambia la batería (como mucho una vez por frame; también en `BeginPlay`). Valor actual: `GetCamouflageBatteryPercent()`. |
| `OnThrowableCountChanged` | `AstronautaCharacter` | `(int32 Remaining)` (-1 = infinitos) | Al lanzar (y una vez en `BeginPlay`). |
| `OnRedAlert` | `StationGameState` | `(AActor* AlarmInstigator)` | Al activarse la alarma (rótulo "ALERTA ROJA"). |
| `OnPlayerCaptured` | `StationGameState` | `(AActor* Player, AActor* CapturedBy)` | Captura / pantalla de Game Over. |
| `OnLightingModeChanged` | `StationLightingDirector` | `(EStationLightingMode NewMode)` | Cambio de atmósfera. |

> Los delegados del jugador se emiten en su `BeginPlay`. Si el widget se crea después, hay que leer el valor inicial con los getters (`IsFlashlightOn`, `GetCamouflageBatteryPercent`, `ThrowablesLeft`, `GetMaxSuspicion`) además de enlazar el evento.

---

## 8. Milestone 4: crafting, terminales y Motion Tracker

### Crafting (`UCraftingComponent`, ya incluido en `AstronautaCharacter`)
| Gadget | Coste | Tiempo |
|---|---|---|
| Noisemaker | 2 Scrap + 1 Sensor | 2.5 s |
| EMPMine | 3 Scrap + 2 Batteries + 1 Chemical | 4.0 s |
| SmokeBomb | 2 Chemicals + 1 Scrap | 3.0 s |
| Medkit | 2 Chemicals + 1 Battery | 2.0 s |

- `StartCraft(Gadget)` / `CancelCraft()` / `CanCraft` / `GetCraftProgress`. Las recetas son editables en el array `Recipes`.
- Los materiales se consumen **solo al completar**. Correr, saltar/caer o recibir daño (`OnTakeAnyDamage`) interrumpe sin gastar nada; si el inventario está lleno, también.
- Delegados: `OnCraftStarted(Gadget, Duration)`, `OnCraftProgress(Percent01)`, `OnCraftCompleted(Gadget)`, `OnCraftInterrupted(Reason)`.

### Terminal de seguridad (`BP_TerminalSeguridad` ← `SecurityTerminal`)
- En la instancia: `Local Lights` (actores de luz, Movable), `Doors` (`StationDoor`), `Steam Vents` (TargetPoints), `Steam Class` (por defecto `SmokeBombActor`).
- `BeginHack(Action, Player)`: hackeo de 3 s. Si el jugador se aleja más de 200 uu, corre o cancela, falla y la terminal emite un pitido audible (1.2 / 1400 uu).
- Acciones: apagar/restaurar luces locales (alterna), sobrecargar esclusas (abre aunque haya Alerta Roja; una vez), purga de vapor (cooldown 20 s).
- Delegados: `OnHackStarted`, `OnHackProgress`, `OnHackFinished(Action, bSuccess)`; evento BP `OnActionExecuted`.

### Motion Tracker y la IA
- El ping a menos de 450 uu se emite con el tag `MotionTrackerPing`. El alien lo reconoce: +25 de sospecha fijos (`SuspicionInstantDelta_TrackerPing`) e Investigar el origen.

---

## 9. Milestone 5: salud, oxígeno y guardado

### `UHealthComponent` (ya incluido en `AstronautaCharacter`)
- Salud 0-100 y oxígeno 0-100. El daño entra por `ApplyDamage` (`OnTakeAnyDamage`) o con `ApplyHealthDamage`.
- **Vacío:** coloca `BP_ZonaVacio` (← `VacuumZone`, una caja) en esclusas y zonas sin presión. Dentro, el oxígeno baja 5/s; a 0, la salud baja 10/s. Fuera, el oxígeno se recarga a 10/s (`OxygenRefillRate`; 0 = sin recarga). Para abrir una esclusa al vacío, llama a `SetVacuumActive` desde el BP.
- **Desangrado** (salud < 40): suelta una `BloodDropActor` cada 1.5 s si el jugador se mueve (3 s si está quieto). La gota es fresca durante 30 s (tag `BloodTrail` y estímulo de Sight) y desaparece a los 90 s. El decal necesita un material de sangre asignado en el BP.
- **IA:** sangre fresca = +30 de sospecha e Investigar la gota (en Patrullar o Investigar), una vez por gota. Como cada gota nueva redirige al alien, este sigue el rastro.
- `ApplyMedkit()`: consume un Medkit y cura 50.
- Delegados: `OnHealthChanged`, `OnOxygenChanged`, `OnBleedingStateChanged`, `OnPlayerDied(Killer)`.

### `ASaveTerminal` (`BP_TerminalGuardado`)
- `BeginSave(Player)`: 2.5 s de inserción de tarjeta, **sin pausa**.
- Bloqueo "HOSTIL CERCANO": si al empezar o al terminar hay a menos de 1000 uu un alien en persecución activa (AlertaRoja viendo al jugador, o corriendo a la alarma), dispara `OnHostileWarning` (BP: parpadeo rojo) y `OnSaveFailed(HostileNearby)`.
- Alejarse más de 200 uu cancela el guardado.
- Delegados: `OnSaveStarted`, `OnSaveProgress`, `OnSaveSuccess`, `OnSaveFailed(Reason)`.
- Carga: `LoadStationGame` (estático) tras abrir el nivel guardado.

### `UStationSaveGame` (slot `StationSave`)
Guarda posición y rotación, salud y oxígeno, recursos y gadgets, alarma y estado de cada `StationDoor` (por nombre de actor; **no renombres puertas** entre versiones del nivel).

---

## 10. Flujo de partida, guardado y ciclo de Game Over

1. **Partida nueva:** abrir el nivel sin opciones.
2. **Guardar:** `ASaveTerminal` (sección 9) escribe en el slot `StationSave`.
3. **Captura o muerte:**
   - Los dos caminos llevan a `AStationGameMode::TriggerGameOver`: `AStationGameState::OnPlayerCaptured` y `UHealthComponent::OnPlayerDied`.
   - Al dispararse, se bloquean movimiento y cámara.
   - Tras `GameOverDelay` (3 s) se pasa a modo de input solo UI con cursor y se dispara el evento BP **`OnGameOverScreenRequested(Cause, Instigator)`**.
   - En `BP_StationGameMode` (hijo de `StationGameMode`, con `BP_Astronauta` como Default Pawn), ese evento crea el widget "SIN SEÑAL / CAPTURADO".
4. **Reintentar:** el botón del widget llama a `RestartFromLastCheckpoint(GetPlayerController(0))`. Esto restaura el input de juego y llama a `ReloadLastSave()`, que hace `OpenLevel(nivel actual, "load=1")`. Si no hay partida guardada, reinicia el nivel desde cero.
5. **Carga:** `BeginPlay` del GameMode detecta `load` en `OptionsString`. Un tick después llama a `ASaveTerminal::LoadStationGame`, que aplica posición, vitales, inventario, alarma y puertas.
6. **Menú principal → Continuar:** `OpenLevel(<nivel>, Options = "load=1")`.

**Compilación:** ejecutar `Scripts\VerifyAndGenerateProject.bat`. El script:
- Comprueba VS 2022 y MSVC (con `vswhere`), el Windows SDK, UE 5.4 y el espacio libre en disco.
- Genera `Astronauta.sln` y compila `AstronautaEditor`.
- Guarda el log en `Saved\Logs\FirstBuild.log`.
