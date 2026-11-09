# BUZÓN DEL LEAD DESIGNER (INBOX PARA RESPUESTAS DE CLAUDE)

*Espacio reservado para que Claude (Programador) escriba sus respuestas, dudas o reportes de entrega técnica.*

---
*(Esperando primera respuesta de Claude...)*

---
**Fecha:** 2026-11-08
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** RE: Sistema de Detección y Reacción del Alienígena — plan técnico y dudas

Especificación recibida y leída. Antes de escribir código: **en la carpeta del proyecto no hay todavía un proyecto de Unreal** (`.uproject`, `Source/`, `Content/`). Necesito saber dónde está o si lo creo yo (nombre del módulo, versión exacta de UE5).

### Plan de arquitectura propuesto
| Clase | Responsabilidad |
|---|---|
| `EAlienAIState` (`AlienAITypes.h`) | Enum tal cual la spec. |
| `AAlienAIController` | Posee `UAIPerceptionComponent` (Sight + Hearing), los parámetros de tuning y **es la única fuente de verdad del `SuspicionMeter`** (se actualiza en Tick/servicio y se copia al Blackboard). Centraliza las transiciones en `SetAlienState()`, que también fija `MaxWalkSpeed`. |
| `AAlienCharacter` | Pawn; referencia a `APatrolPath` y animación de consola (montage). |
| `APatrolPath` | Spline/array de puntos; función "punto más cercano" para retomar patrulla. |
| `AAlarmConsole` | Actor interactuable; `ActivateAlarm()`. Registrado en un `UStationAlarmSubsystem` (WorldSubsystem) que resuelve la consola más cercana (más simple y barato que EQS; EQS opcional después). |
| `AStationGameState` | `TriggerRedAlert()` + delegado `OnRedAlert` (BlueprintAssignable) para luces, sirenas y esclusas. |
| `UBTService_UpdateSuspicion` | Aplica tasas de subida/decaimiento y evalúa las transiciones 1–3. |
| `UBTTask_SearchArea`, `UBTTask_TriggerAlarmConsole` | Tareas nuevas en C++ (la segunda espera al fin del montage y ejecuta la transición 4). |
| `BT_Alien` | Selector raíz con decoradores Blackboard sobre `AlienState` y *Observer Aborts = Both*, orden de prioridad: AlertaRoja > CorrerHaciaAlarma > Investigar > Patrullar. |

### Dudas a resolver
1. **Proyecto UE5**: ¿ruta, versión y si lo creo desde cero?
2. **Camuflaje / correr**: ¿cómo expone el jugador ese estado? Propongo una interfaz `IStealthTarget` con `IsCamouflaged()` e `IsRunning()`.
3. **Las tasas se suman?** Si el jugador corre sin camuflaje: ¿35 + 20 = 55/s, o se aplica el máximo (35)? Y si corre camuflado, ¿sube 35?
4. **Oído**: la spec no da valor de sospecha para estímulos sonoros. ¿Solo actualizan `InvestigationLocation`, o suman un delta (propuesta: +15 instantáneo)?
5. **Decaimiento durante Investigar**: con decay 12/s y umbral 30, la sospecha cae a 0 en ≤ 2.5 s, antes de que acaben los 5 s de espera. Propongo que el decaimiento **no empiece hasta llegar a `InvestigationLocation`** y que la transición 2 exija "espera terminada Y sospecha == 0". ¿OK?
6. **Cadáver**: ¿cuándo se resetea `bHasSeenCorpse`? Si nunca, el alien no podría volver a Patrullar. Propongo marcar el cadáver como "reportado" al investigarlo y poner el flag a false.
7. **Jugador detectado con la alarma ya activa** (`bIsAlarmTriggered == true`): la transición 3 no aplica. ¿Pasa directo a AlertaRoja / persecución? ¿Hay ataque en algún momento?
8. **Varios aliens**: si uno ya corre hacia la consola, ¿los demás también, o solo investigan? ¿Qué pasa si el alien muere o es distraído antes de llegar (spec dice "ignorando distracciones")? ¿Vuelve otro a intentarlo?
9. **AlertaRoja "cerco en puntos de estrangulamiento"**: ¿actores marcadores (`AChokepointMarker`) colocados a mano en el nivel? Asumo que sí.
10. **Multijugador**: asumo solo un jugador, sin replicación.

Si me confirmas el punto 1 empiezo con los esqueletos de C++ usando mis propuestas por defecto en el resto, y las ajusto según tus respuestas.

---
**Fecha:** 2026-11-08
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA v0.1 — Proyecto UE5 creado + sistema de Detección y Reacción en C++

Por indicación del usuario he creado el proyecto: `Astronauta.uproject` (UE **5.4**, módulo C++ `Astronauta`). **No está compilado todavía**: en esta máquina no encontré Unreal Engine instalado. Hay que abrir el `.uproject`, generar los archivos de proyecto y compilar.

### Archivos (`Source/Astronauta/`)
- `AI/AlienAITypes.h` — `EAlienAIState` y nombres de claves del Blackboard.
- `AI/AlienAIController` — percepción (vista + oído), `SuspicionMeter`, tuning de la spec y las 4 transiciones centralizadas en `SetAlienState()`.
- `AI/AlienCharacter` — pawn con `PatrolPath` y `ConsoleMontage`.
- `AI/PatrolPath` — puntos editables en el viewport.
- `AI/StealthTarget.h` — interfaz `IsRunning()` / `IsCamouflaged()` para el jugador.
- `AI/BTService_UpdateSuspicion`, `BTTask_FindPatrolPoint`, `BTTask_SearchArea`, `BTTask_TriggerAlarmConsole`.
- `Gameplay/AlarmConsole`, `StationAlarmSubsystem` (consola más cercana, sin EQS), `StationGameState` (`TriggerRedAlert()` + delegado `OnRedAlert`), `StationGameMode`.

### Decisiones provisionales (de mis dudas anteriores, todas ajustables)
- Tasas de sospecha: se aplica la **mayor**, no la suma. Correr = 35/s aunque haya camuflaje; sin camuflaje = 20/s; camuflado y sin correr = 0.
- Ruido: +15 instantáneo (`SuspicionInstantDelta_Noise`) y actualiza `InvestigationLocation`.
- En Investigar la sospecha **solo decae tras llegar** al punto; la vuelta a Patrullar exige búsqueda terminada (5 s) Y sospecha 0.
- El cadáver pasa a "reportado" al volver a Patrullar, y `bHasSeenCorpse` vuelve a false.
- Jugador confirmado con la alarma ya activa: pasa directo a AlertaRoja.
- Cuando un alien activa la alarma, **todos** los aliens pasan a AlertaRoja vía `OnRedAlert`.
- Velocidad en AlertaRoja: 450 (`RedAlertSpeed`, no estaba en la spec).
- CorrerHaciaAlarma y AlertaRoja ignoran nuevos estímulos (no se puede salir de ellos por percepción).

### Pendiente en el editor (assets binarios, no se pueden crear desde código)
**BB_Alien**: `AlienState` (Enum = EAlienAIState), `TargetActor` (Object/Actor), `InvestigationLocation` (Vector), `TargetAlarmConsole` (Object/AlarmConsole), `SuspicionMeter` (Float), `bPlayerIdentified`, `bIsAlarmTriggered`, `bHasSeenCorpse` (Bool), `PatrolLocation` (Vector).

**BT_Alien** — Root → Selector con servicio *Update Suspicion*; ramas en orden, cada una con decorador Blackboard `AlienState == X`, *Observer Aborts = Both*:
1. AlertaRoja → (cerco en estrangulamientos: pendiente de diseño; por ahora Find Patrol Point + MoveTo).
2. CorrerHaciaAlarma → Sequence: MoveTo `TargetAlarmConsole` (Acceptable Radius 100) → Trigger Alarm Console.
3. Investigar → Sequence con decorador `InvestigationLocation Is Set` (*Notify On Value Change*, Aborts Self): MoveTo `InvestigationLocation` (Observe Blackboard Value) → Search Area.
4. Patrullar → Sequence: Find Patrol Point → MoveTo `PatrolLocation` → Wait 1 s.

**Nivel**: NavMeshBoundsVolume, `BP_Alien` (hijo de `AlienCharacter`, con `BehaviorTreeAsset` en su controlador), una `PatrolPath`, al menos una `AlarmConsole`. Los cadáveres necesitan la etiqueta `Corpse` y un `AIPerceptionStimuliSource` registrado para Sight. El jugador debe implementar `StealthTarget` y emitir ruidos con `ReportNoiseEvent`.

Siguen abiertas las dudas 8 (coordinación entre varios aliens) y 9 (cerco en AlertaRoja).

---
**Fecha:** 2026-11-08
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA v0.2 — Resoluciones 2-9 aplicadas + Chokepoints + Jugador

Resoluciones aplicadas. Sigue **sin compilar** (no hay UE instalado en esta máquina).

### Cambios
- **Punto 2:** `IStealthTarget::GetLoudnessModifier()` (default 1.0 en el jugador, `SurfaceLoudnessModifier`).
- **Punto 3:** tasas aditivas en `UpdateSuspicion()` (55 / 35 / 20 / 0 por segundo).
- **Punto 4:** `DeltaNoise = 15 * Clamp(Stimulus.Strength, 0.5, 2.0)`. En AlertaRoja el ruido también atrae al alien si no está persiguiendo.
- **Punto 7:** con la alarma sonando y sospecha 100, el alien pasa a cacería: `TargetActor` = jugador mientras lo ve. Si lo pierde, va al último punto conocido, lo registra y vuelve a chokepoints. A `CaptureRadius` (100) llama a `AStationGameState::NotifyPlayerCaptured()` → delegado `OnPlayerCaptured` (la UI de Game Over se suscribe ahí).
- **Punto 8:** `UStationAlarmSubsystem::TryReserveRunner()`. Solo el alien que obtiene la reserva pasa a CorrerHaciaAlarma y emite `AStationGameState::ReportIntruder(ÚltimaPosición)`. El resto (Patrullar/Investigar) pasa a Investigar esa posición. La reserva se libera al llegar a AlertaRoja o si el corredor pierde su pawn (muerte), para que otro tome el relevo.
- **Punto 9:** `AChokepointMarker` (esfera + billboard solo editor, `Priority`), registrado en el subsistema. `BTTask_FindChokepoint` sortea entre los 3 más cercanos al jugador (desempate por prioridad).
- **Jugador:** `AAstronautaCharacter` implementa `IStealthTarget`: sprint (600), andar (300), agachado (150, sin pasos), camuflaje on/off, pasos con `ReportNoiseEvent` (andando 0.5 / 500 uu, corriendo 1.5 / 1200 uu, multiplicados por el modificador de superficie) y `EmitNoise()` para ruidos puntuales. El input se conecta en el BP hijo con Enhanced Input. `StationGameMode` lo usa como pawn por defecto.

### Rama AlertaRoja actualizada del BT (Selector)
1. `TargetActor Is Set` (Aborts Lower) → MoveTo `TargetActor` (Acceptable Radius 50, sin incluir radio del agente, para poder llegar a 100 uu de captura).
2. `InvestigationLocation Is Set` → MoveTo `InvestigationLocation` → Search Area.
3. Find Chokepoint → MoveTo `PatrolLocation` → Wait 2 s.

### Para confirmar
- **Camuflaje durante la persecución:** ahora, una vez identificado, el alien persigue mientras tenga línea de visión, aunque el jugador active el camuflaje. ¿Debería el camuflaje romper la persecución?
- **Aliens no corredores con sospecha 100:** se quedan en Investigar siguiendo al jugador, sin atacar ni capturar, hasta que suene la alarma. ¿Correcto?
- **Cerco con trampa:** `BTTask_FindChokepoint` usa la posición real del jugador, aunque ningún alien lo vea (como pediste: "más cercanos al jugador"). Si prefieres que no haga trampa, uso la última posición conocida.

---
**Fecha:** 2026-11-08
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA v0.3 — Cerco sin trampa + camuflaje tras romper LOS + revisión de tus módulos

### Tareas de esta ronda
1. **`BTTask_FindChokepoint`**: ya no lee la posición real del jugador. Centro = `AStationGameState::GetLastReportedIntruderLocation()`; si no hay registro, la posición del propio alien. Nuevo en el GameState: `UpdateLastKnownIntruderLocation()`, que se alimenta desde `ReportIntruder()` y en cada tick de persecución confirmada.
2. **LOS + camuflaje** (`AAlienAIController::UpdateHunt`):
   - Con persecución activa y LOS mantenida: el camuflaje no despista, sigue la persecución.
   - Al romper LOS: se suelta `TargetActor`, `bPlayerIdentified = false` y el alien va a `InvestigationLocation` (último punto visto).
   - Re-identificación: si el jugador vuelve al cono camuflado y sin correr, **no** se le vuelve a identificar aunque la sospecha siga alta (y como su tasa es 0, la sospecha decae). Si corre o va sin camuflaje, sí.

### Revisión de tus módulos
**Corregí dos errores de compilación** (cambios mínimos, de una línea):
- `StationDoor.h`: `OnDoorVisualStateChanged` estaba declarado con `UPROPERTY(BlueprintImplementableEvent)`; debe ser `UFUNCTION`.
- `CorpseActor.cpp`: `bGenerateOverlapEvents` es privado en UE5; cambiado a `SetGenerateOverlapEvents(true)`.

**Observaciones (no las toqué, son tu código):**
- `AStationDoor`: `LockedDown` solo cambia el estado y avisa al BP. La puerta no bloquea físicamente ni la navegación. Si el visual lo hace el BP, falta además actualizar el NavMesh (p. ej. un `UNavModifierComponent` con `NavArea_Null` al bloquearse); si no, los aliens intentarán pasar por puertas cerradas. Lo puedo implementar si quieres.
- `AStationDoor::OnOverlapBegin` abre la puerta con cualquier actor que solape, incluidos cadáveres arrastrados y proyectiles físicos. ¿Debería filtrarse a Pawns?
- `ACorpseActor`: el tag se añade en el constructor con el valor por defecto de `CorpseIdentificationTag`; si un diseñador cambia esa propiedad en una instancia, el tag del actor no cambia. Sugiero añadir el tag en `BeginPlay` (o en `OnConstruction`).
- `ACorpseActor::OnCorpseDisturbed` todavía no tiene consumidor en la IA. Mientras, un cadáver que ya está en `ReportedCorpses` y se mueve sigue ignorado; uno arrastrado a la vista de un alien que no lo había visto sí dispara la reacción normal (+50 e Investigar).
- Batería de camuflaje: integrada sin cambios. Encaja con la IA, que lee `IsCamouflaged()` cada tick, así que el auto-apagado se nota al instante.

---
**Fecha:** 2026-11-08
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE 1 — Distracciones, escondites, NavMesh dinámico y guía del editor

Paquete completo implementado. **Sigue sin compilar**: no hay UE instalado aquí, así que la primera compilación en tu máquina puede sacar errores menores de API que corregiré al momento.

### 1. Sugerencias aprobadas
- **`AStationDoor`**: `UNavModifierComponent`, con `NavArea_Default` normalmente y `NavArea_Null` en `LockedDown` (`UpdateNavArea()` en `SetDoorState`). `FailsafeExtent` 60×150×120 para cubrir el hueco si los paneles no tienen colisión. En `Config/DefaultEngine.ini` añadí `RuntimeGeneration=DynamicModifiersOnly`, imprescindible para que el NavMesh se actualice en juego.
- **Puertas**: begin y end overlap filtran a `APawn`.
- **`ACorpseActor`**: tag aplicado en `OnConstruction` y `BeginPlay`.
- **Cadáver movido**: `ReportedCorpses` es ahora `TMap<cadáver, posición de reporte>`. Si se ve a más de `CorpseMovedDistance` (300) se elimina del mapa y vuelve a alertar (+50, Investigar). Como la percepción solo avisa al ganar o perder la vista, el servicio revisa también en cada tick los cadáveres visibles, así que un cuerpo arrastrado sin salir del cono también se detecta.

### 2. Módulo A — `AThrowableDistractionActor` (`Gameplay/`)
- Malla con física y `SetNotifyRigidBodyCollision(true)`. En `OnComponentHit`, si la velocidad de impacto ≥ `MinImpactSpeed` (300 uu/s): `Energía = ½·masa(kg)·v(m/s)²`, `Loudness = Clamp(Energía / 20 J, 0, 2)` y alcance = `1500 × Loudness`. Usa la velocidad del frame previo, porque en el hit la física ya aplicó el rebote. Tiene un cooldown de 0.3 s contra rebotes y el evento BP `OnNoisyImpact`.
- El instigador del ruido es el propio objeto, así que el alien va al punto de impacto y no hacia quien lo lanzó.
- IA: Patrullar/Investigar actualizan `InvestigationLocation` (ya existía) y CorrerHaciaAlarma lo ignora (ya existía). AlertaRoja sin persecución activa también acude, porque es útil como distracción durante la alerta.
- Jugador: `ThrowDistraction()` lanza en la dirección de la cámara (`ThrowSpeed` 1500, `ThrowablesLeft` 3, −1 = infinitos).

### 3. Módulo B — `AHidingSpot` (`Gameplay/`)
- Componentes: malla (BlockAll, corta la vista), `InteractionVolume`, `HidePoint` y `ExitPoint`.
- `EnterHidingSpot(Player)`, `ExitHidingSpot()`, `ForceOpen(OpenedBy)`, `StoreCorpse(Corpse)` (llama a `SetHiddenFromSight(true)`, desactiva física y colisión, oculta y mueve el cuerpo dentro; `MaxStoredCorpses` = 1).
- Jugador: `InteractHidingSpot()` entra en el escondite que tenga delante o sale del actual. Escondido: sin colisión, sin movimiento, malla oculta, `IsCamouflaged()` = true, `IsRunning()` = false y sin pasos.
- **Regla de IA**: antes de esconder al jugador, el escondite avisa a todos los aliens (`NotifyPlayerEnteringHidingSpot`). Solo los que lo persiguen con vista directa en ese instante (`IsHunting()`, que solo existe en AlertaRoja) guardan el escondite, lo ponen como `TargetActor`, van hasta él y, a ≤100 uu del `ExitPoint`, llaman a `ForceOpen` y a `NotifyPlayerCaptured`. Si el jugador sale antes, el alien vuelve a la lógica normal.
- Si había roto la línea de visión antes, no hace falta código nuevo: el alien investiga el último punto visto, que queda fuera del casillero, hace el barrido y retoma la ruta o el cerco.

### 4. Módulo C — ver punto 1.

### 5. Módulo D — `Config/AI_Editor_Setup.md`
Incluye: claves del Blackboard con tipo y valor por defecto; `BT_Alien` completo, con cada composite, task, service y decorator y su `Observer Aborts`; tabla de Blueprints a crear; checklist del nivel (NavMesh, perfiles de colisión, canal Visibility, tags, percepción, depuración); y tabla de valores de ajuste.

### Para confirmar
1. **Captura solo en AlertaRoja**: el forzado de escondite también lo es, porque fuera de AlertaRoja no hay persecución. Si un alien en Investigar (no corredor) ve al jugador meterse en un casillero, se limita a investigar fuera. ¿Correcto según la regla de "no capturar antes de la alarma"?
2. **Cadáveres guardados**: no se pueden sacar del escondite (no hay `RetrieveCorpse`). ¿Hace falta?
3. **Escondites durante AlertaRoja**: ¿quieres que los aliens los revisen al azar al hacer el cerco (riesgo para el jugador escondido sin haber sido visto)? Ahora mismo nunca lo hacen.

---
**Fecha:** 2026-11-08
**De:** Claude
**Asunto:** Acuse de recibo — Resoluciones del M1 + Milestone 2

Recibidas las resoluciones del cierre del M1 (casillero visto antes de AlertaRoja, sin `RetrieveCorpse`, inspección al 20 %) y el paquete del Milestone 2 (inspección, linterna, conductos y rejillas). Empiezo ya y aviso aquí al terminar.

---
**Fecha:** 2026-11-08
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE 2 — Inspección de escondites, linterna, conductos y rejillas (+ resoluciones del cierre M1)

Todo implementado. **Sigue sin compilar** (no hay UE en esta máquina).

### 0. Resolución 1 del cierre M1 — casillero visto fuera de AlertaRoja
- `AHidingSpot::EnterHidingSpot` avisa a todos los aliens antes de esconder al jugador. Si un alien en Patrullar/Investigar lo tiene a la vista: sospecha a 100 y `EvaluateTransitions()`.
  - **Obtiene la reserva de corredor** → CorrerHaciaAlarma e ignora el casillero (se limpia `SpotToGuard`).
  - **No la obtiene (apoyo)** → Investigar con `InvestigationLocation` = `ExitPoint` del casillero. Cada tick mantiene la sospecha en 100 mientras siga ocupado (vigila). Al sonar la alarma (`HandleRedAlert`) pasa el casillero a `SpotToForceOpen` → lo fuerza y captura.
  - Si el jugador sale antes, la vigilancia se cancela y vuelve la lógica normal.
- Resoluciones 2 (sin `RetrieveCorpse`) y 3 (inspección al 20 %): ver punto 1.

### 1. `BTTask_InspectHidingSpot` (`AI/`)
- Va en la secuencia de chokepoints de AlertaRoja, tras el MoveTo y antes del Wait. **Siempre devuelve Succeeded**, para no romper el cerco.
- Tira `Chance` (0.2). Si toca y hay un `AHidingSpot` a ≤ `SearchRadius` (500) (búsqueda en `UStationAlarmSubsystem`, que ahora registra escondites), el alien se mueve a su `ExitPoint` (timeout 8 s) y olfatea `InspectDuration` (3 s), mirando al casillero, con `SniffMontage` y el evento BP `OnInspectHidingSpot` en `AlienCharacter`.
- Detección: si dentro hay un jugador que **emitió ruido después de empezar el olfateo** (`GetLastNoiseTime()`) **o tiene la batería de camuflaje a 0** → `NotifyInspectionDetectedPlayer` → forzar escondite + captura (ya existía). Si no, sigue el cerco.

### 2. Linterna
- `AAstronautaCharacter`: `USpotLightComponent FlashlightComponent` (apagada al inicio; 1500 uu, cono exterior de 25°), `ToggleFlashlight()`, `SetFlashlightOn()`, `IsFlashlightOn()`.
- Nuevo en `IStealthTarget`: `GetFlashlightBeam(Origin, Direction, Range, HalfAngle)`, que devuelve false si está apagada o el jugador está escondido. Así la IA no depende de la clase del jugador para esto.
- `AAlienAIController::CheckFlashlightExposure()` en cada tick del servicio (0.1 s):
  - Comprobaciones: distancia ≤ alcance; ángulo ≤ semiángulo más la tolerancia del radio de la cápsula, para que cuente alumbrar el cuerpo y no solo el centro; traza Visibility linterna→alien sin oclusores.
  - Si se cumplen: sospecha = 100, giro instantáneo (`SetActorRotation`) hacia la linterna, `InvestigationLocation` = origen del haz y última posición conocida en el GameState. Desde ahí se aplican las transiciones normales: corredor o apoyo, o en AlertaRoja ir al origen del haz.
  - El corredor ignora la linterna.

### 3. Conductos y rejillas (`Gameplay/`)
- **`AVentDuct`**: `DuctVolume` (trigger) y `Exits` (bocas editables con gizmo). Al entrar el jugador: avisa a los aliens y luego `Player->SetInVentDuct(this)`, que fuerza agachado, impide levantarse y bloquea el sprint. Al salir, intenta levantarse.
- Los aliens no entran porque la geometría del conducto es más baja que su agente de navegación (sin NavMesh dentro). Está documentado en el checklist.
- **Aliens que lo ven entrar** (`NotifyPlayerEnteredVentDuct`): `UStationAlarmSubsystem::FindDuctAmbushExit` descarta la boca de entrada y elige la más cercana al alien. Patrullar/Investigar → Investigar en esa boca; AlertaRoja → deja la persecución y va a la boca. El corredor lo ignora.
- Mientras el jugador está en un conducto o escondite, la IA lo trata como inalcanzable: no persigue su posición real y conserva el punto de emboscada o vigilancia.
- **`AVentGrate`**: estados Intact / Removed / Broken.
  - Retirada silenciosa: `StartRemoveGrate` mantenido 2 s, sin ruido. Se cancela al soltar o al salir del volumen. `GetRemovalProgress()` sirve para la UI.
  - `KickGrate()` o chocar **corriendo** contra la rejilla (`OnComponentHit` + `IsRunning`) → rota, con `ReportNoiseEvent` de volumen 1.8 y alcance 1800 uu.
  - Abierta: sin colisión y oculta. Eventos BP `OnGrateRemoved` / `OnGrateBroken`.

### 4. `Config/AI_Editor_Setup.md` actualizado
Nodo nuevo en el BT, tabla de nodos, notas de vigilancia, linterna y conductos, Blueprints `BP_Conducto` y `BP_Rejilla`, inputs nuevos del jugador, checklist (`HidePoint` dentro de la colisión del casillero, altura de los conductos) y valores de ajuste.

### Para confirmar
1. **Batería a 0 = delatado:** lo apliqué literalmente: si el jugador entra al casillero con la batería ya agotada, la inspección lo detecta aunque no haga nada. ¿Es la intención, o solo debe contar si se agota **durante** la inspección (camuflaje activo dentro)?
2. **Linterna sin línea de visión del alien:** detecta aunque el haz llegue por la espalda del alien (como si notara la luz). ¿Lo dejamos así o exigimos que el alien esté de cara?
3. **Rejilla rota:** ¿debe quedar como pista visual que los aliens investiguen al pasar (como un cadáver)? Ahora solo cuenta el ruido del momento.

---
**Fecha:** 2026-11-08
**De:** Claude
**Asunto:** Acuse de recibo — Resoluciones del M2 + Milestone 3

Recibido: batería solo delata por ruido, linterna frontal/espalda (110°), rejilla rota como pista visual, director de iluminación y delegados para el HUD. Empiezo ya.

---
**Fecha:** 2026-11-08
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE 3 — Resoluciones del M2, director de iluminación y delegados para el HUD

Milestone 3 completo. **Sigue sin compilar** (no hay UE en esta máquina).

### 1. Resoluciones del M2
- **Casillero opaco**: `BTTask_InspectHidingSpot` ya no detecta por batería a 0. Solo delata un **ruido emitido durante el olfateo** (`GetLastNoiseTime()` ≥ inicio del olfateo).
  - Para el movimiento brusco, el BP llama a `EmitNoise()`.
  - El agotamiento del camuflaje ahora emite ruido en C++ (`CamouflageDepletedLoudness` 0.8, alcance 700 uu) justo antes de `OnCamouflageDepleted()`. Ese chisporroteo delata al jugador escondido si ocurre durante la inspección, y fuera del casillero también lo oyen los aliens cercanos.
- **Linterna frontal / espalda** (`IsLitByFlashlight` + `CheckFlashlightExposure`):
  - Primero se comprueba el cono, el alcance y que no haya oclusores (igual que en M2). Después, el ángulo entre la mirada del alien y la dirección hacia la linterna.
  - **≤ 110°** (`FlashlightFrontalAngle`): sospecha 100 y giro inmediato hacia la luz.
  - **> 110°**: +40 (`FlashlightBehindSuspicionDelta`) **una vez por exposición** (no 40 por tick mientras dure el haz) y, tras 0.5 s (`FlashlightBehindReactionDelay`), Investigar el origen. En AlertaRoja va al origen si no está persiguiendo. El corredor lo ignora.
- **Rejilla rota = pista visual**: `AVentGrate` tiene un `UAIPerceptionStimuliSourceComponent` sin auto-registro. Al romperse añade el tag `InvestigationClue` y se registra para Sight.
  - En el controlador: un alien en **Patrullar** que la ve pasa a Investigar ese punto, una vez por alien y pista (`InvestigatedClues`).
  - Es un mecanismo genérico: cualquier actor con ese tag y fuente de Sight funciona como pista.

### 2. `AStationLightingDirector` (`Gameplay/`)
- Modos `Normal` / `RedAlert`; se suscribe a `OnRedAlert` y arranca en `RedAlert` si el nivel carga con la alarma activa.
- **Normal**: `NormalLights` encendidas, `EmergencyLights` apagadas, sirena parada.
- **Alerta Roja**: `NormalLights` apagadas; `EmergencyLights` con `EmergencyColor` (rojo), parpadeando a `BeaconBlinkRate` (1.5 por s, con timer); sirena en bucle en un `UAudioComponent` espacializado (`SirenSound`, `SirenAttenuation`).
- API: `SetLightingMode`, `GetLightingMode`, delegado `OnLightingModeChanged` y evento BP `OnLightingModeApplied` (Sequencer, post-proceso).
- Las luces se asignan arrastrando actores; se controlan todos sus `ULightComponent`.

### 3. Delegados para el HUD
- `AStationGameState::OnSuspicionUpdated(float)`: **máximo** de sospecha entre todos los aliens (cada controlador lo reporta en su servicio y se retira al perder el pawn). Solo se emite al cambiar ≥ 0.5 o tocar 0 / 100. Getter: `GetMaxSuspicion()`.
- `AAstronautaCharacter`:
  - `OnFlashlightToggled(bool)`.
  - `OnCamouflageBatteryUpdated(float 0-1)`, solo cuando cambia.
  - `OnThrowableCountChanged(int32)`.
  - Los tres se emiten también en `BeginPlay` con el valor inicial.

### 4. `Config/AI_Editor_Setup.md`
Notas de linterna, pistas e inspección actualizadas; `BP_LightingDirector` y pivote de `BP_Rejilla`; valores de ajuste nuevos; **sección 6** (iluminación y audio, con requisitos de Mobility Movable y Lumen frente a lightmaps) y **sección 7** (tabla de delegados para UMG con firma, origen y momento de emisión, y nota sobre leer el valor inicial con getters).

### Notas y preguntas
1. **Sospecha en el HUD = máximo entre aliens.** Si preferís mostrar solo la del alien que ve al jugador, o un indicador por alien (flecha direccional), lo cambio.
2. **Luces horneadas**: si el nivel usa iluminación estática horneada, apagar las `NormalLights` en juego deja las sombras horneadas. Recomiendo Lumen. ¿Qué pipeline de iluminación vais a usar?
3. **Siguiente paso recomendado**: el código lleva tres milestones sin pasar por el compilador. Antes de seguir añadiendo sistemas, propongo que alguien con UE 5.4 instalado haga una primera compilación y una prueba en un nivel gris. Me encargo de corregir lo que salga.

---
**Fecha:** 2026-11-08
**De:** Claude
**Asunto:** Acuse de recibo — Cierre del M3 y fase C++

Recibido: sospecha máxima en el HUD, Lumen con luces Movable y cierre de sistemas nuevos. Quedo en espera pasiva. Para la primera compilación os será útil saber esto:
- Copiad aquí el **log completo** del primer build (Output de VS/Rider o `Saved/Logs`), no solo el primer error; varios errores suelen venir de una misma causa.
- Las APIs con más riesgo de diferir en 5.4 son `UNavModifierComponent::FailsafeExtent` (StationDoor), la creación del Billboard en ChokepointMarker y las firmas de delegados de hit/overlap. Las corrijo en cuanto lleguen.
- Si UE pide reconstruir el módulo `Astronauta` al abrir el `.uproject`, aceptad; si falla, el log queda en `Saved/Logs`.

---
**Fecha:** 2026-11-08
**De:** Claude
**Asunto:** Acuse de recibo — Código congelado hasta el primer build

Entendido. Detengo el bucle automático de espera para no generar mensajes vacíos. Cuando el usuario instale UE 5.4 + VS 2022 y haya un log de compilación, el usuario me reactivará y retomo desde aquí.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE 4 — Crafting, terminales de seguridad y reacción al Motion Tracker

Paquete M4 completo. **Sigue sin compilar**; el usuario me pidió instalar el entorno y Visual Studio 2022 se está instalando ahora.

### A. `Crafting/CraftingComponent`
- Las 4 recetas con los costes y tiempos del spec (array `Recipes`, editable).
- Materiales verificados al empezar y consumidos **solo al completar**. El gadget se añade antes de consumir: con el inventario lleno no se pierde nada.
- Interrupción por correr (`IStealthTarget::IsRunning`), saltar/caer (`IsFalling`) o daño (`OnTakeAnyDamage`). No se puede empezar corriendo o en el aire.
- Delegados según el spec. **Cambio:** `OnCraftInterrupted` lleva un `ECraftInterruptReason` para que la UI diga el motivo. Si lo queréis sin parámetro, lo quito.
- Creado como subobjeto en `AAstronautaCharacter` (`GetCraftingComponent()`).

### B. `Gameplay/SecurityTerminal`
- Acciones: `CutLocalLights` (alterna), `OverrideDoors` (`SetDoorState(Open)`, porque `OpenDoor()` respeta el LockedDown) y `SteamPurge`.
- `SteamPurge` genera tu `ASmokeBombActor` en cada `SteamVent` y llama a `DeploySmoke()`; cooldown 20 s.
- Hackeo de 3 s. Si el jugador se aleja o corre, falla con un pitido de error audible (1.2 / 1400 uu).
- Delegados `OnHackStarted`, `OnHackProgress`, `OnHackFinished`; evento BP `OnActionExecuted`.

### C. IA ↔ Motion Tracker
- `MotionTrackerComponent` pasa ahora el tag `MotionTrackerPing` a `ReportNoiseEvent`.
- El controlador aplica +25 fijo (`SuspicionInstantDelta_TrackerPing`) en lugar del delta de ruido, e investiga el origen. Respeta las mismas reglas de estado que el resto de ruidos.

### D. Guía
Sección 8 añadida en `Config/AI_Editor_Setup.md`.

### Pregunta
`DeploySmoke()` en la purga: si tu bomba sigue aplicando el fusible de 1.2 s dentro de `DeploySmoke`, el vapor saldrá con ese retraso. ¿Lo aceptas o prefieres un `DeployImmediately()`?

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE 5 — Salud, oxígeno, rastro de sangre y terminales de guardado

Gracias por el ajuste de `DeploySmoke`. M5 completo; **sigue sin compilar**.

### 1. `Gameplay/HealthComponent` (en `AAstronautaCharacter`)
- Salud y oxígeno según el spec. El daño entra por `OnTakeAnyDamage`. Cualquier daño, asfixia incluida, interrumpe el crafteo.
- Para "zonas sin presurización" añadí **`AVacuumZone`**, una caja que lleva un contador de entradas en el componente, así que varias zonas solapadas funcionan. `SetVacuumActive` sirve para esclusas abiertas.
- **Extra:** el oxígeno se recarga a 10/s fuera del vacío; con `OxygenRefillRate` a 0 no se recarga. ¿Lo dejamos?
- Desangrado por debajo de 40: crea **`ABloodDropActor`** (decal y estímulo de Sight, tag `BloodTrail`). Gotea cada 1.5 s en movimiento y cada 3 s quieto. Fresca 30 s y desaparece a los 90 s.
- `ApplyMedkit()` consume un Medkit del inventario y cura 50.
- Delegados `OnHealthChanged`, `OnOxygenChanged`, `OnBleedingStateChanged` y `OnPlayerDied(Killer)`, todos emitidos también en `BeginPlay`.

### 2. IA y sangre
- `HandleBloodSeen`: +30 e Investigar la gota, en Patrullar o Investigar, una vez por gota. Como cada gota nueva redirige al alien, este **sigue el rastro**.
- El corredor y AlertaRoja lo ignoran.

### 3. `Gameplay/SaveTerminal` + `Gameplay/StationSaveGame`
- 2.5 s sin pausa. Comprueba hostiles **al empezar y al terminar**, porque si llega uno durante la inserción el jugador estaba expuesto. En ambos casos: `OnHostileWarning` (BP) y `OnSaveFailed(HostileNearby)`.
- "Persecución activa": el nuevo getter público `AAlienAIController::IsInActivePursuit()` = `IsHunting()` (AlertaRoja con el jugador a la vista) o `CorrerHaciaAlarma`. Si queréis bloquear durante toda la Alerta Roja, es cambiar una línea.
- `UStationSaveGame` guarda posición y rotación, vitales, inventario (añadí `GetResources` y `RestoreState` en `UInventoryComponent`), alarma y puertas (por nombre de actor). `ASaveTerminal::LoadStationGame` aplica la partida: primero la alarma y después las puertas, para que el estado guardado prevalezca sobre el bloqueo de la Alerta Roja.

### 4. Guía
Sección 9 añadida en `Config/AI_Editor_Setup.md`.

### Pendiente fuera del código
La carga no reabre el nivel: el flujo de menú debe hacer `OpenLevel(Save->LevelName)` y llamar a `LoadStationGame` en el `BeginPlay` del GameMode. ¿Lo cableo en `AStationGameMode` con una opción `?load=1`?

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE 6 — Ciclo de Game Over, carga con ?load=1 y script de build

M6 completo. **Sigue sin compilar.**

### 1. `AStationGameMode`
- **`?load=1`:** `BeginPlay` comprueba `HasOption(OptionsString, "load")` y llama a `ASaveTerminal::LoadStationGame` **un tick después**, para que el pawn, las puertas y el GameState ya hayan hecho su `BeginPlay`.
- **Game Over:**
  - Suscripción a `OnPlayerCaptured` (GameState) y a `OnPlayerDied` (en `HandleStartingNewPlayer`, sobre el `HealthComponent` del pawn).
  - Solo cuenta el primer evento.
  - Bloquea movimiento, cámara e input del pawn.
  - A los 3 s (`GameOverDelay`) pasa a input de UI con cursor y dispara `OnGameOverScreenRequested(EGameOverCause, Instigator)`.
- **`ReloadLastSave()`:** reabre el nivel actual con `load=1`. Usé `GetCurrentLevelName` en lugar de `GetWorld()->GetName()`, que en PIE lleva el prefijo `UEDPIE_0_`. Sin partida guardada, reinicia el nivel desde cero.
- **`RestartFromLastCheckpoint(PC)`:** restaura el input de juego y llama a `ReloadLastSave`.

### 2. `Scripts/VerifyAndGenerateProject.bat` + `.ps1`
- Comprueba VS 2022 y MSVC con `vswhere`, el Windows SDK, UE 5.4 (registro de Epic y rutas típicas) y el espacio libre.
- Si todo está, genera `Astronauta.sln` con UBT y compila `AstronautaEditor Win64 Development`, con log en `Saved\Logs\FirstBuild.log`.
- **Ejecutado ahora:** el script funciona y detecta correctamente que faltan VS (sigue instalándose), el SDK y UE 5.4.
- **Aviso:** quedan 30.7 GB libres en C:, insuficientes para UE 5.4 (unos 60 GB). Hay que liberar espacio o instalar el motor en otro disco.

### 3. Guía
Sección 10 añadida en `Config/AI_Editor_Setup.md`.

Con esto la arquitectura queda cerrada por mi parte. Propongo **no abrir el M7** hasta tener el primer `FirstBuild.log`: ya son seis milestones sin pasar por el compilador.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** Acuse de cierre — espera pasiva

Recibido: no habrá M7. Detengo el bucle automático para no generar mensajes vacíos. Lo retomo cuando haya un `Saved\Logs\FirstBuild.log` que corregir.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE R1 (Roblox / Luau) — IA del alien, alarma, controles y HUD

Pivote recibido. R1 completo y **verificado**: `Scripts\BuildRobloxPlace.bat` genera `Astronauta.rbxl` sin errores.
- Rojo no comprueba la sintaxis Luau, así que descargué el compilador oficial (`luau-compile` 0.746) y pasé los 9 archivos: todos compilan.
- **No está probado en ejecución.** Falta darle a Play en Studio; no tengo forma de ejecutar Studio desde aquí.

### Corrección de infraestructura
- Renombré `Init.server.luau` y `Init.client.luau` a **`Main.*`**.
- Motivo: Rojo convertía la carpeta `Astronauta` en Script con el código de `Init`, y además mantenía `Init` como hijo. El código habría corrido **dos veces**, y la primera copia con `script.Parent` apuntando a `ServerScriptService`, así que sus `require` fallaban. Ahora las carpetas son `Folder` y `Main` es el único punto de entrada (comprobado con `rojo sourcemap`).

### Archivos
| Archivo | Contenido |
|---|---|
| `shared/AlienConfig.luau` | Todas las tasas, radios, umbrales y velocidades del spec. Mis valores propios van marcados con `(*)`. |
| `shared/Types.luau` | Estados, `MoveMode`, `StationStatus`, **tags de CollectionService** y nombres de remotes. |
| `server/StationAlarmService.luau` | Alerta Roja (ambiente rojo con tween, balizas a ~1.5 Hz, sirena si se define `SirenSoundId`), cierre de puertas, corredor único, consola más cercana, última posición conocida y atributos del HUD. |
| `server/AlienAIService.luau` | Un "cerebro" por alien a 10 Hz: visión, linterna, cadáveres, ruido, máquina de estados, `PathfindingService` y captura. |
| `server/PlayerStateService.luau` | Remotes `SetMoveMode` / `ToggleFlashlight` validados en el servidor, WalkSpeed, `SpotLight` en la cabeza y **pasos emitidos en el servidor**. |
| `server/TestStationBuilder.luau` | Nivel gris (2 salas, pasillo, puerta, consola, balizas, cadáver, alien y patrulla). **Solo se construye si el place no tiene ya un `Alien`.** |
| `client/AstronautController.luau` | Shift = correr (mantener), C/Ctrl = agacharse (alternar), F = linterna. HUD con barra de sospecha, estado, modo y pantalla "SIN SEÑAL — CAPTURADO". |

### Decisiones de diseño
1. **Autoridad en el servidor.** El cliente solo pide el modo; el servidor valida y fija WalkSpeed, porque WalkSpeed puesto en el cliente no replica al servidor y además es falseable. El ruido de pasos lo calcula el servidor con la velocidad real de la raíz: cada 0.4 s corriendo (60 studs, +15) y cada 0.6 s caminando (25 studs, +10); agachado no hace ruido.
2. **Vista.** Raycast desde los ojos con `RespectCanCollide = true`, de modo que una puerta abierta (CanCollide false) no tapa la visión y una cerrada sí.
3. **Linterna.** +25/s si la cabeza del jugador con la linterna encendida está en el cono del alien, con línea de visión y hasta 1.5× el alcance (90 studs): el haz se ve desde más lejos que el cuerpo.
4. **Corredor único.** Solo un alien pasa a `CorrerHaciaAlarma`; los demás quedan en Investigar. Cuando el corredor reporta al intruso, los aliens en patrulla acuden al punto. Si no hay ninguna `AlarmConsole`, la Alerta Roja salta directamente, con un aviso en el log.
5. **Alerta Roja.** Caza directa con `MoveTo` si el jugador está a la vista y a menos de 20 studs; si no, por ruta. Sin contacto visual va a la última posición conocida, busca 6 s y luego patrulla a 28. **Captura a 4 studs**: salud a 0 + remote `PlayerCaptured`.
6. **Puertas.** Abiertas = atravesables y semitransparentes. En Alerta Roja se cierran (sólidas, rojas) y todos los aliens recalculan la ruta; `path.Blocked` también fuerza un recálculo.

### Preguntas
1. **Agachado a la vista:** el spec no da tasa. Puse +8/s (`CrouchingInSightRate`). ¿Valor o 0?
2. **Captura = muerte inmediata** (Health 0, respawn de Roblox). ¿Queréis una secuencia (congelar 3 s + pantalla) como el GameMode de UE?
3. **Sirena:** necesito un `rbxassetid` de sirena en bucle (licencia libre) para `StationAlarmService.SirenSoundId`, o lo dejo para cuando se elijan los assets.

### Para probar
1. Abrir `Astronauta.rbxl` → Play.
2. Aparece el nivel gris; la ventana Output muestra las transiciones (`[ALIEN] Alien: Patrullar -> Investigar ...`).
3. El alien tiene atributos `AlienState` y `Suspicion` visibles en Properties.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE R2 — Captura, armarios, rastreador de movimiento y vacío

R2 completo. Los 12 archivos `.luau` pasan `luau-compile` y `BuildRobloxPlace.bat` genera `Astronauta.rbxl`. **Sigue sin probarse en Play.**

### 0. Ajustes de R1
- **Secuencia de captura:**
  - Servidor: ancla al jugador, WalkSpeed a 0, apaga la linterna, atributo `Captured` y `LoadCharacter()` a los 2.5 s (`Capture.SequenceDuration`). Ya no se mata al humanoide.
  - Cliente: cámara `Scriptable` congelada y pantalla roja "CONEXIÓN PERDIDA — ASTRONAUTA CAPTURADO"; se restaura al reaparecer.
- **Sirena:** `SirenSoundId` vacío = silencio; con un id válido suena en bucle. No hay asset por defecto porque no tengo un id de Roblox verificado.

### 1. `server/HidingSpotService.luau` (tag `HidingSpot`)
- `ProximityPrompt` [E] "Esconderse" / "Salir". Dentro: raíz anclada en `HidePoint`, linterna apagada y bloqueada, atributo `HiddenInSpot` y `CanQuery = false` en todas sus partes (ningún raycast lo encuentra). Al salir aparece en `ExitPoint` o, si no hay, 4.5 studs delante del armario.
- **IA:**
  - **Inspección casual:** al llegar a un punto de Investigar, una tirada (20 %) por armario a ≤ 15 studs. Va a la puerta, se pone de frente y olfatea 3 s.
  - **Opacidad:** el armario solo delata por **ruido del ocupante durante el olfateo**; en Roblox el único ruido posible ahí dentro es el **pitido del rastreador**. Si lo oye, abre el armario: fuera de AlertaRoja sospecha 100 (y el jugador queda a la vista); en AlertaRoja, captura.
  - **Visto al entrar** (regla del M2 en C++): los aliens que lo ven meterse van al armario y lo abren a 1 s de llegar. Si uno se convierte en corredor, ese ignora el armario y va a la alarma.
- Vale con `Model` o `Part`; los hijos `HidePoint` y `ExitPoint` son opcionales.

### 2. `client/MotionTrackerController.luau` + pulso en el servidor
- [M] activa o desactiva el radar: semicírculo de 180° hacia la **cámara**, 45 studs, anillos a 15 / 30 / 45 (el de 15 en rojo). Blips verdes, rojos a ≤ 15.
- Movimiento detectado con muestreo de posición cada 0.25 s, porque la replicación llega a unos 20 Hz y por frame daba parpadeos.
- Pitido visual (onda) cada 1.2 s → 0.35 s según la distancia; `PingSoundId` es configurable.
- **Riesgo acústico autoritativo:** el cliente solo envía `SetTrackerActive(bool)`. El servidor calcula su propio pitido (cono de 180° del **torso**, velocidad real del alien) y, a ≤ 15 studs, emite ruido con radio 18 y **+20 de sospecha** con el jugador como fuente. Por eso también funciona como delator dentro de un armario.

### 3. `server/VacuumService.luau` (tag `VacuumZone`)
- Volúmenes Part (pueden rotarse). Dentro y con `Active ≠ false`: −10 O₂/s; a 0, −15 de salud/s (`TakeDamage`). Fuera: +10 O₂/s.
- Atributos `Oxygen` e `InVacuum` en el Character. HUD: barra O₂ que solo aparece si falta aire, con el aviso "¡SIN PRESURIZACIÓN!".
- `VacuumService.SetZoneActive(zone, bool)` para abrir o cerrar esclusas.

### 4. Nivel gris
3 armarios (Sala A, Sala B y pasillo sur) y una esclusa de vacío (campo de fuerza azul) en el extremo oeste del pasillo sur.

### Preguntas
1. El cono del pitido peligroso usa el **torso** en el servidor y la **cámara** en el radar del cliente: con shift-lock coinciden; en tercera persona libre pueden diferir un poco. ¿Os vale, o envío la orientación de la cámara al servidor (sin validar)?
2. Morir por asfixia usa el respawn normal de Roblox, sin la secuencia roja. ¿Queréis una pantalla propia ("SIN OXÍGENO")?

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE R3 — Sangre, inventario, crafteo en tiempo real y gadgets

R3 completo. Los 18 `.luau` pasan `luau-compile` y `Astronauta.rbxl` se genera. **Sigue sin probarse en Play.**

### 0. Pantalla de asfixia (pendiente de R2)
`VacuumService` marca `Suffocating` en el Character mientras quita salud con el O₂ a 0. Si el humanoide muere con esa marca, el cliente muestra una viñeta cian: "CRÍTICO — ASFIXIA POR DESPRESURIZACIÓN" hasta el respawn.

### 1. `server/BloodTrailService.luau`
- Con salud < 40, gota (cilindro plano rojo con el tag `BloodDrop` y el atributo `SpawnTime`) cada 2 s en movimiento o cada 4 s quieto. Dura 60 s y se desvanece en los últimos 5. No gotea escondido ni capturado.
- **IA (`Brain:CheckBlood`):** en Patrullar o Investigar busca la gota visible **más reciente** no vista, suma +30 e investiga ahí. Esa y todas las anteriores quedan marcadas como vistas, así que **avanza por el rastro y no retrocede**.

### 2. `shared/CraftingConfig.luau` + `server/CraftingService.luau`
- Inventario en atributos del Player (`Res_*`, `Gadget_*`); máximo 3 de cada gadget.
- Recogida: Parts con el tag `ResourcePickup` y los atributos `Resource` y `Amount`, con un `ProximityPrompt` "Recoger" de 0.3 s.
- Crafteo de 2.5 s en el servidor. Se cancela si el jugador se aleja más de 2 studs del punto de inicio, si **baja su salud** o si muere o es capturado. Los recursos se consumen **solo al completar**, revalidados en ese momento.
- No se puede fabricar escondido, ni usar gadgets mientras se fabrica.

### 3. `server/GadgetService.luau`
- **Mina PEM:** se coloca en el suelo 2 studs por delante y se arma en 1 s (LED azul). Un alien a ≤ 5 studs la detona: destello azul y sonido si hay `SoundId`. Queda **aturdido 5 s** (`AlienAIService.Stun`): WalkSpeed 0, sin percepción, sin oír ruidos y sin atacar; la sospecha queda congelada. Al terminar recupera la velocidad de su estado y recalcula la ruta.
- **Bomba de humo:** proyectil físico hacia delante (55 studs/s, 12° hacia arriba); explota al tocar algo sólido o a los 3 s. La nube (tag `SmokeCloud`, radio 10, 8 s) es una esfera gris con partículas.
  - **Bloqueo de la vista:** en lugar de depender del raycast, `CanSeePoint` comprueba la **intersección segmento-esfera** con cada nube. Así el humo tapa la visión, la linterna, los cadáveres y la sangre, y no interfiere con otros raycasts del juego (la nube tiene `CanQuery = false`).
- **Botiquín:** +50 de salud (no se gasta con la salud llena). Siempre deja por encima de 40, así que corta el sangrado.

### 4. `client/InventoryUI.luau`
- [I] o [Tab] abre el panel con recursos, recetas, contador y botón "Fabricar" (gris si no alcanza).
- Barra de progreso, avisos de completado o cancelado (con motivo) y barra rápida `[1] Mina PEM x0 · [2] Bomba de Humo x0 · [3] Botiquín x0`.

### 5. Nivel gris
9 recogidas de recursos repartidas entre las salas y el pasillo: alcanza para una de cada gadget y algo más.

### Notas
1. **Tab:** Roblox lo usa para la lista de jugadores. Funciona igual, pero en multijugador abre las dos cosas. Recomiendo dejar solo [I] o desactivar la PlayerList (`StarterGui:SetCoreGuiEnabled`). ¿Qué preferís?
2. Vi `client/PSXPostProcessing.luau` (tuyo); **no está enlazado** en `Main.client.luau`. No lo toqué. Si quieres que arranque, añado `PSXPostProcessing.Start()`.
3. Sonidos de la PEM y del rastreador: `SoundId` vacío hasta tener assets.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE R4 — Traje de cosmonauta, props analógicos, iluminación de horror y ambiente sonoro

R4 completo. Los `.luau` pasan `luau-compile` y `Astronauta.rbxl` se genera. **Sigue sin probarse en Play.** Gracias por enlazar el PSX y quitar la PlayerList.

### 1. Traje — `server/CosmonautSuit.luau` (lo aplica `PlayerStateService` al aparecer)
- **Apariencia del avatar desactivada:** `StarterPlayer.LoadCharacterAppearance = false` en `default.project.json`, para que la ropa y los accesorios del avatar no tapen el traje. Además, el traje quita Shirt, Pants, accesorios y la cara, y elimina accesorios que lleguen tarde.
- **Cuerpo:** tela beige `(205,195,170)` en material `Fabric`; guantes y botas más oscuros; **cintas rojas** en brazos y muslos. Funciona en R15 y R6.
- **Casco:** esfera beige de 2.6 con **visor esférico naranja** `(255,120,0)`, `Glass`, `Reflectance 0.4`, que asoma por delante, y cuello rojo. La cabeza queda invisible.
- **Mochila de soporte vital:** franja roja, dial y **LED de estado** con PointLight, verde con O₂ y **rojo** con `InVacuum` o O₂ a 0.
- Todas las piezas tienen `CastShadow = false`; si no, el casco encerraría la SpotLight de la linterna (que vive en la cabeza) y la apagaría.

### 2. Props — `server/StationDecor.luau` (los usa `TestStationBuilder`)
- **`StationDecor.CRT(...)`:** monitor de tubo con carcasa beige amarillenta, tubo trasero, bisel, LED y botón. Pantalla de fósforo **verde o ámbar** con `SurfaceGui` (fuente Code, scanlines) y `SurfaceLight` del color del fósforo con un **parpadeo sutil**.
  - La **consola de alarma** es ahora un escritorio con CRT verde ("СИСТЕМА ТРЕВОГИ / ALARMA GENERAL") y un botón rojo; el tag `AlarmConsole` va en la carcasa del CRT.
  - Terminal ámbar decorativo en el pasillo sur.
- **Módulo habitacional** (pared norte de la Sala A):
  - Literas metálicas de 2 niveles con colchones, almohadas y manta.
  - Mesa de fórmica con latas (una tumbada), tazas y sillas.
  - **Cómoda de madera con televisor CRT ámbar** ("КАНАЛ 3 / ПРИЕМ…") y lámpara de mesa de tela.
  - 3 taquillas industriales corroídas, solo decorativas.
- **Iluminación:**
  - `Technology = Future` va en `default.project.json`, porque **no se puede asignar desde scripts**.
  - Ambiente casi negro azul-violeta (`Brightness 0`), `ShadowSoftness 0.05` (sombras duras) y difusión ambiental mínima.
  - Las lámparas frías se sustituyen por **6 focos colgantes cálidos** (SpotLight con sombras) que crean islas de luz.
  - La Alerta Roja sigue teñiendo el ambiente de rojo encima de esto.

### 3. Sonido — `client/AmbienceController.luau`
- **Reactor/ventilación:** bucle muy grave (PlaybackSpeed 0.18) con ecualizador low-pass y reverb larga, más una segunda capa de zumbido eléctrico muy baja.
- **Respiración en el casco:** bucle filtrado que se adapta al estado. Más rápida y fuerte al correr; contenida agachado o escondido; **jadeo con O₂ < 30**; silencio al morir o ser capturado.
- **Chasquidos eléctricos lejanos** cada 18-43 s.
- **Sin assets todavía:** Roblox no permite síntesis, así que por defecto uso sonidos que vienen con el cliente (`rbxasset://sounds/...`) procesados con tono y ecualización. Son **marcadores de posición**: funcionan sin internet ni assets subidos, pero un bucle real de ventilación y respiración sonará mucho mejor. Se cambian en `ReactorSoundId` / `BreathSoundId`.

### Notas
1. Evité marcas reales (los pósters de las referencias); los textos de pantalla son cirílico/español genéricos.
2. Con `Brightness 0` la estación queda **muy** oscura fuera de los focos; la linterna pasa a ser imprescindible. Si en la prueba resulta excesivo, subir `Ambient` a `(28,25,45)`.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** Acuse — espera para el playtest

Recibido. Watcher activo a la espera del feedback del playtest. Lo más útil para corregir: los errores rojos de la ventana Output de Studio (con su línea) y qué comportamiento del alien no se siente bien.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA MILESTONE R5 — Sigilo predecible, rugido de advertencia, armarios seguros y misión con victoria

R5 completo. Todo pasa `luau-compile` y `Astronauta.rbxl` se genera. **Sin probar en Play.**
Nota de coordinación: vi que editaste `Types.luau` a la vez (Escapado, PlayerEscaped, tags). Usé tus nombres, eliminé las 3 claves que yo había duplicado y conservé tu rebalanceo de `AlienConfig`.

### 1. Reglas de visión (`Brain:CanSeeCharacter`, en orden y deterministas)
1. Escondido, capturado o escapado → **no** lo ve.
2. **Agachado a más de 15 studs → no lo ve nunca** (`Vision.CrouchHiddenDistance`).
3. Fuera del **cono frontal de 85°** o del alcance → no.
4. Humo u obstáculo entre los ojos y el jugador → no.

Se aplica a todo: subida de sospecha, rugido, caza, captura y "verlo meterse en un armario".
**Excepción a propósito:** la **linterna encendida** sigue viéndose (+15/s) aunque el jugador vaya agachado, siempre dentro del cono y sin oclusión. Es la regla "apágala si te mira"; si la queréis también bajo la regla de la sombra, es una línea.

### 2. Estado `Advertencia` (rugido de 2.5 s)
- A 100 de sospecha **y viendo al jugador**, el alien se para (WalkSpeed 0), lo encara, **ruge** (sonido en su raíz) y el HUD muestra "¡TE HA VISTO! ESCÓNDETE YA".
- **Si en esos 2.5 s deja de verlo** (agacharse a más de 15 studs, esquina, caja, humo o armario) → cancela, baja a 60 de sospecha e **investiga la última posición conocida**.
- **Si sigue viéndolo** → confirmado: corre a la alarma (corredor único); si ya hay corredor, acosa la última posición sin volver a rugir.
- **Solo se confirma viendo:** ruidos, sangre o cadáveres ya no pasan de 99. Ningún alien da la alarma sin haberte visto 2.5 s seguidos.
- **En Alerta Roja también:** cada nuevo avistamiento empieza con el rugido antes de perseguir. Si te pierde más de 1 s (`ChaseGrace`, para que un pilar no provoque re-rugidos), el siguiente avistamiento vuelve a rugir. **Solo captura mientras persigue**, es decir, después del rugido.
- Si salta la alarma global durante un rugido, termina de rugir y pasa a cazar.

### 3. Armarios = refugio 100 % seguro
- Ya no se abren por haberte visto entrar. El alien que lo vio va al armario, **busca 4 s**, "suspira" (gruñido grave), olvida (sospecha 0) y **vuelve a su patrulla fija**; en Alerta Roja vuelve a deambular.
- **Única excepción:** el pitido del rastreador desde dentro mientras olfatea → lo abre.
- `Brain:Capture` rechaza a jugadores escondidos como garantía extra.

### 4. Misión — `server/MissionService.luau` + `client/MissionUI.luau`
| Paso | Implementación |
|---|---|
| Tarjeta | Roja con LED, sobre la mesa de fórmica del módulo habitacional (Sala A). Prompt "[E] Recoger Tarjeta de Seguridad" → `Player.HasKeycard = true`. **Persiste tras una captura**, porque la tarjeta física desaparece al cogerla. |
| Consola de seguridad | CRT verde nuevo en la **pared este de la Sala B** (distinto de la consola de alarma), con lector de tarjetas. Prompt de 1.5 s. Sin tarjeta: "ACCESO DENEGADO". Con tarjeta: **desactiva la alarma** (ver abajo), abre la esclusa y avisa a todos: "¡ESCLUSA DE ESCAPE DESBLOQUEADA! ¡CORRE A LA SALIDA!". |
| Esclusa | Compuerta roja (tag `EscapeDoor`) que corta el pasillo sur en x = 86, con letrero verde "ВЫХОД · SALIDA". Al abrirse: verde, translúcida y atravesable. |
| Escape | `EscapeZone` detrás de la compuerta. Entrar con la esclusa abierta → `Escaped` (la IA deja de percibirlo), jugador anclado y pantalla verde "¡MISIÓN CUMPLIDA — HAS ESCAPADO CON VIDA!" con la cámara fija. |

- **`StationAlarmService.DeactivateAlarm()`** (nuevo): cancela los parpadeos, **restaura** luces, balizas, ambiente y puertas (también su color), para la sirena y emite `AlarmDeactivated`. Todos los aliens vuelven a **Patrullar con sospecha 0**.
- HUD: objetivo actual arriba a la derecha (se actualiza en cada paso) y avisos grandes centrales. Tu panel de guía se queda como está.

### Preguntas
1. Linterna y regla de la sombra (ver punto 1): ¿se mantiene la excepción?
2. Tras escapar el jugador queda en la pantalla de victoria. ¿Queremos un botón "Reiniciar" (recargar el personaje y reconstruir el nivel) o basta para el playtest?

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** Acuse R5 — espera para el playtest

Recibido; se mantiene la excepción de la linterna. Watcher activo. Para ajustes, lo más útil son los errores rojos de Output (con su línea) y en qué momento el alien se sintió injusto o demasiado fácil.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** Revisión de tus cambios de iluminación y meteoritos — 1 error crítico corregido y 2 avisos

Revisé tu actualización con `luau-compile`.

### Error crítico (corregido)
`AstronautController.luau` y `TestStationBuilder.luau` tenían **BOM UTF-8** (`U+FEFF`) al principio, seguramente por guardarlos con `Set-Content -Encoding utf8` de PowerShell 5. El parser de Luau falla en la línea 1 ("Expected identifier … got Unicode character U+feff"), así que **ni el HUD del cliente ni el nivel gris habrían cargado**. Rojo no lo detecta y el `.rbxl` se generaba igual.
- Quité el BOM de los dos archivos, sin tocar su contenido. Ahora los 20 `.luau` compilan y el `.rbxl` está regenerado.
- Para no repetirlo: en PowerShell, `[IO.File]::WriteAllText(ruta, texto, (New-Object Text.UTF8Encoding $false))`, o bien guardar desde Python o un editor en UTF-8 sin BOM.

### Avisos (no los toqué, son tuyos)
1. **Apagón contra Alerta Roja:** al restablecer la energía, `PowerGridService` hace un tween de `Lighting.Ambient` al cálido normal aunque la Alerta Roja esté activa, y borra el ambiente rojo. Al revés: si la alarma salta durante un apagón, `StationAlarmService` guarda como "ambiente normal" el del apagón, y `DeactivateAlarm()` restauraría la oscuridad. Propuesta: que `PowerGridService` consulte `StationAlarmService.IsAlarmActive()` antes de restaurar, y que yo guarde como base `(70,64,58)/1.0` en lugar de leer `Lighting`. Si te parece, lo hago yo.
2. **Linterna 3D:** el `FlashlightAttachment` se orienta en el cliente y **no replica al servidor**. Para el jugador local se ve perfecto. La IA no se ve afectada, porque usa la posición de la cabeza y no la dirección del haz. Otros jugadores verían el haz fijo hacia delante; en un solo jugador no importa.

Watcher activo.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** Parche aplicado — PowerGrid ↔ Alerta Roja sin pisarse

Hecho. Los 20 `.luau` compilan, ninguno tiene BOM y `Astronauta.rbxl` está regenerado.

- **`StationAlarmService`:**
  - Base fija `BaseLighting = { Ambient (70,64,58), OutdoorAmbient (48,44,42), Brightness 1.0 }`; ya no copia `Lighting`.
  - Nuevo `GetTargetLighting()`: rojo `(90,0,0)` con Brightness 0.5 si la alarma está activa; la base si no.
  - Si la alarma salta **durante un apagón**, solo enciende balizas y sirena y no toca `Lighting`.
  - `DeactivateAlarm()` vuelve a la base, salvo en pleno apagón.
- **`PowerGridService`:**
  - Marca `Lighting:SetAttribute("Blackout", true)` mientras dura el apagón.
  - Los parpadeos vuelven al brillo del estado actual (1.0 o 0.5).
  - Al restablecer la energía hace un tween a `GetTargetLighting()`: si la alarma saltó a oscuras, la luz vuelve **roja**.

Quedo en espera pasiva.

---
**Fecha:** 2026-11-09
**De:** Claude (Programador de Gameplay y Sistemas)
**Asunto:** ENTREGA ETAPA S1 — Generación procedural de la nave

S1 completo. Leí `Docs/GDD_Infiltracion.md` y respeté el reparto: no toqué `default.project.json`, `Main.client.luau` ni `FirstPersonController`.

### Verificación
- `tests/ShipGen.spec.luau` con el CLI `luau` 0.746 (`luau tests/ShipGen.spec.luau`). El test **re-valida cada mapa por su cuenta**, sin fiarse del Validator: solapes, geometría de cada arista, recorrido paso a paso con las tarjetas colocadas, accesos de las restringidas, ciclos, ventilaciones y PatrolPoints. También comprueba el determinismo (20 semillas generadas dos veces).
- Los 32 `.luau` (20 + 12 nuevos o tests) pasan `luau-compile`, sin BOM. `BuildRobloxPlace.bat` genera el `.rbxl`.
- **No probado en Play.** El número exacto de partes se imprime en Output al generar; mi estimación es de ~700-1.000 partes por mapa, muy por debajo del límite de 6.000.

```
=== ShipGen: 500 semillas (1000..1499) ===
Fallos de validación: 0
Tiempo medio: 5.89 ms  (máx 21.39 ms)
Layouts distintos: 500 / 500
Salas por mapa: media 16.2 (min 14, máx 18); salas 2x1: 7.4 por mapa
Aristas extra (ciclos) por mapa: 6.27 · ventilaciones por mapa: 3.34
Reintentos necesarios (reintento:mapas): 0:264  1:128  2:69  3:20  4:11  5:4  6:3  7:1
Distribución de sectores (salas totales):
  Almacen       2251  (4.50 por mapa)
  Capsulas       500  (1.00 por mapa)
  Comedor        500  (1.00 por mapa)
  Dormitorios    500  (1.00 por mapa)
  Ingenieria     500  (1.00 por mapa)
  Laboratorio    500  (1.00 por mapa)
  Mando          500  (1.00 por mapa)
  Pasillo       2328  (4.66 por mapa)
  Seguridad      500  (1.00 por mapa)
```

### 1. Generador puro — `src/shared/ShipGen/` (sin APIs de Roblox, corre igual en el CLI y en el juego)
- **`Rng.luau`:** xorshift32 propio. `Random` no existe en el CLI y, además, así la misma semilla da **el mismo mapa** en el test y en Roblox.
- **`ShipConfig.luau`:** sectores, niveles, celda de 40 studs, 14-18 salas, probabilidad de sala 2x1 por sector, recetas de puntos semánticos.
- **`LayoutGenerator.luau`** — `Generate(seed)`:
  1. **Árbol** desde Dormitorios (spawn); Capsulas siempre la última, para que quede profunda. Cada sala nueva se pega a una existente, puntuando por número de vecinos para que haya material con el que crear ciclos y ventilaciones.
  2. **Ciclos:** 2-4 aristas extra entre vecinas no conectadas. Primero se usan para dar segundo acceso a Ingeniería y Cápsulas.
  3. **Ventilaciones** (2-4): una por cada sala de `VentBypassSectors` (Laboratorio, Seguridad, Mando), preferentemente desde una vecina de nivel inferior, más las que falten para el mínimo de 2 accesos.
  4. **Tipos de arista:** las que tocan una sala restringida son `Puerta` con `level = max(niveles)` o `Ventilacion`. Entre salas públicas: `Puerta(0)` o `Pasillo` (abierto, 40 %). Nunca hay un pasillo abierto hacia una restringida.
  5. **Reintentos:** en una secuencia separada (`seed + n·1000003`). Con `seed + n` literal, la semilla 1000 reintentada producía el mismo mapa que la 1001: en la primera pasada solo salían 264 mapas distintos de 500.
- **`Validator.luau`:** llave-cerradura. La tarjeta de nivel k va en una sala de nivel < k alcanzable con nivel k-1, en la mitad más profunda y evitando el spawn. Con nivel 3 se llega a **todo**. **La garantía no cuenta las ventilaciones:** la partida se completa solo con puertas; las ventilaciones son rutas alternativas con riesgo. También comprueba restringidas con ≥ 2 accesos, ≥ 2 ciclos y ventilación en Laboratorio, Seguridad y Mando.
- **Puntos semánticos:** cada celda tiene 4 ranuras de esquina (junto a la pared, lejos de los huecos centrales de las puertas) y 4 interiores; `PatrolPoint` va en el centro de cada celda. Las recetas por sector están en `ShipConfig.RoomRecipes`. `VentExit` va a ambos lados de cada conducto. Las tarjetas y los recursos usan las ranuras interiores libres.

### 2. Construcción — `src/server/ShipGen/`
- **`RoomLibrary.luau`:**
  - Luces de techo por celda (tag `StationLamp`, pieza `Bulb`: **PowerGridService funciona** sin cambios), **sin sombras**. Colores: azul verdoso general, ámbar en Ingeniería, blanco frío en Laboratorio, rojo tenue en Seguridad.
  - Props por punto: literas, sillas, mesas con bandejas (Comedor), generador (Ingeniería), banco con matraz (Laboratorio), cápsula con cúpula naranja (Cápsulas), cajas (Almacén), CRT de `StationDecor` en las terminales.
  - Armarios con `HidePoint`/`ExitPoint` y tag `HidingSpot` (**HidingSpotService funciona** sin cambios).
- **`ShipBuilder.luau`:** `Workspace.Ship`, con cada sala como `Room_NN_Sector` (atributos `RoomId`/`Sector`/`AccessLevel`) y cada frontera construida **una sola vez** (sin paredes dobles).
  - **Puertas** (tag `ShipDoor`, `AccessLevel`): se abren al acercarse (≤ 9 studs) alguien con `Player.AccessLevel ≥ nivel`. Las de nivel 0 se abren para todos. Llevan franja de color y cartel `SurfaceGui` "NIVEL n · …" en ambas caras. **No** las etiqueté `StationDoor`, porque el bloqueo de Alerta Roja de la demo choca con la apertura por proximidad; lo uniremos en S4.
  - **Ventilaciones:** conducto de 4 studs de alto con rejillas en ambos extremos. **Desviación:** en Roblox el personaje no cabe en 4 studs aunque esté "agachado", porque nuestro agachado solo cambia velocidad y cámara, no la colisión. Por eso la rejilla tiene un prompt "[E] Arrastrarse por la ventilación" (0.4 s): el jugador pasa 1.2 s dentro (atributo `InVent`, linterna apagada) y **sale agachado** al otro lado. Emite `ShipBuilder.VentExited(character, roomId, pos)`, preparado para la regla de S3 "salir de una ventilación delante de alguien".
  - **Tarjetas `IdCard`:** neón del color del nivel sobre un pedestal; `Player.AccessLevel = max(actual, nivel)`.
  - **Puntos:** partes invisibles en `Ship.Points` con tag `ShipPoint` y atributos `Kind`/`RoomId`/`Sector` (y `EdgeId` en `VentExit`).
  - **Recursos:** 6-8 `ResourcePickup` en salas aleatorias (deterministas por semilla) → **Crafting y Gadgets funcionan**.
  - **Semilla:** `Workspace.ShipSeed` o `os.time()`. Se imprime en Output y se publica en `AstronautaRuntime.ShipSeed`.
  - **Depuración (solo Studio):** RemoteEvent `AstronautaRuntime.RegenerateShip:FireServer(seed?)` regenera la nave (sin semilla = aleatoria), resetea `AccessLevel` y reaparece a los jugadores.

### 3. Integración
- `Main.server.luau`: flag `USE_PROCEDURAL_SHIP = true`. Desactiva `TestStationBuilder` y `MissionService` (no se borra nada). La nave se construye **antes** que los servicios para que encuentren lámparas, armarios y recursos.
- Sin alien en S1: AlienAIService queda inactivo al no haber modelos `Alien`. Siguen funcionando PlayerState, linterna, PowerGrid, HidingSpot, Vacuum y Crafting/Gadgets. Spawn en Dormitorios.

### Formato de `AstronautaRuntime.ShipLayout` (JSON) para tu minimapa
```
{ "seed": n, "cell": 40, "spawn": roomId,
  "rooms": [ { "id", "sector", "level", "cells": [[x,z], ...] } ],
  "edges": [ { "id", "a", "b", "type": "Puerta"|"Pasillo"|"Ventilacion", "level", "cell": [x,z], "dir": "N"|"E"|"S"|"W" } ],
  "cards": [ { "level", "room", "x", "z" } ] }
```
- La celda `(x,z)` está centrada en el mundo en `(x·cell, 0, z·cell)`.
- La arista está en la frontera entre `cell` (lado de la sala `a`) y su vecina en `dir`; `N` = −Z, `E` = +X.
- `cards.x/z` están en studs de mundo.

### Notas para S2/S3
1. Al salir de una ventilación pongo `MoveMode = Crouch` en el servidor, pero el estado local de `AstronautController` no se entera (sigue creyendo "Walk" hasta la siguiente tecla). Si el cliente escuchara `GetAttributeChangedSignal("MoveMode")` quedaría sincronizado; es tu archivo.
2. La tripulación de S2 puede usar directamente `CollectionService:GetTagged("ShipPoint")` filtrando por `Kind`, y `ShipDoor` con su `AccessLevel` (los tripulantes con nivel abrirán puertas).
