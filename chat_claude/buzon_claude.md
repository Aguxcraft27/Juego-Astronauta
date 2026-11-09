# MENSAJE DEL LEAD TECHNICAL DESIGNER A CLAUDE (PROGRAMADOR)
**Fecha:** 2026-11-08  
**Asunto:** Especificación Técnica: Sistema de Detección y Reacción del Alienígena (UE5)

Claude, aquí tienes la especificación técnica para implementar la mecánica central de detección y respuesta de la IA. Implementa la lógica en C++ / Behavior Tree siguiendo exactamente estas directrices.

---

### 1. Variables Necesarias y Tipos

#### Enumerador de Estados
```cpp
UENUM(BlueprintType)
enum class EAlienAIState : uint8
{
    Patrullar           UMETA(DisplayName = "Patrullar"),
    Investigar          UMETA(DisplayName = "Investigar"),
    CorrerHaciaAlarma   UMETA(DisplayName = "Correr Hacia Alarma"),
    AlertaRoja          UMETA(DisplayName = "Alerta Roja")
};
```

#### Blackboard Keys / Estado del AIController
*   `AlienState` (`EAlienAIState` / Enum): Estado actual que gobierna la ejecución del Behavior Tree.
*   `TargetActor` (`AActor*` / Object): Puntero al actor que genera el estímulo (Jugador / Cadáver).
*   `InvestigationLocation` (`FVector` / Vector): Coordenadas espaciales del último estímulo sonoro/visual.
*   `TargetAlarmConsole` (`AActor*` o `AAlarmConsole*` / Object): Referencia a la consola de alarma más cercana en la sala de control.
*   `SuspicionMeter` (`float`, rango `[0.0f, 100.0f]`): Medidor acumulativo de sospecha procesado en el componente de percepción.
*   `bPlayerIdentified` (`bool`): Indicador de confirmación positiva de la presencia humana.
*   `bIsAlarmTriggered` (`bool`): Flag global de alarma activa en el nivel/GameState.
*   `bHasSeenCorpse` (`bool`): Flag de avistamiento de un cadáver no reportado.

#### Parámetros de Ajuste / Tuning (Floats en AI Controller / Character)
*   `SuspicionIncreaseRate_Running` (`float` = `35.0f` / seg): Incremento si el jugador corre dentro del cono de visión.
*   `SuspicionIncreaseRate_NoCamouflage` (`float` = `20.0f` / seg): Incremento continuo si el jugador está en línea de visión directa sin camuflaje activo.
*   `SuspicionInstantDelta_Corpse` (`float` = `50.0f`): Incremento inmediato al registrar un cadáver en el cono de visión.
*   `SuspicionDecayRate` (`float` = `12.0f` / seg): Tasa de enfriamiento del medidor cuando no hay estímulos activos.
*   `Threshold_Investigate` (`float` = `30.0f`): Límite de sospecha para entrar en fase de búsqueda.
*   `Threshold_ConfirmPlayer` (`float` = `100.0f`): Límite de sospecha que confirma la identidad del intruso.
*   `PatrolSpeed` (`float` = `250.0f`): `MaxWalkSpeed` en patrulla.
*   `InvestigateSpeed` (`float` = `380.0f`): `MaxWalkSpeed` en investigación.
*   `SprintToAlarmSpeed` (`float` = `700.0f`): `MaxWalkSpeed` en carrera hacia la consola.
*   `AlarmInteractionRadius` (`float` = `150.0f`): Distancia de frenado e interacción con la consola.

---

### 2. Estados del Behavior Tree

1.  **`Patrullar` (Default)**:
    *   **Comportamiento**: Recorrido secuencial entre nodos de ruta (`PatrolPath`) usando `BTTask_MoveTo` a velocidad `PatrolSpeed`.
    *   **Percepción**: Sensores de `UAIPerceptionComponent` activos (Sight y Hearing).
2.  **`Investigar`**:
    *   **Comportamiento**: Desplazamiento a `InvestigateSpeed` hacia `InvestigationLocation`. Ejecuta `BTTask_Wait` y rotación de búsqueda en el área (`BTTask_SearchArea`).
    *   **Evaluación**: `UBTService` evalúa la persistencia del estímulo; si no hay nuevos eventos, decrementa `SuspicionMeter`.
3.  **`CorrerHaciaAlarma`**:
    *   **Comportamiento**: Prioridad crítica. Bloquea cualquier rama de ataque directo.
    *   **Navegación**: Consulta al subsistema de estación o EQS para resolver `TargetAlarmConsole` en la sala de control. Ejecuta `BTTask_MoveTo` a `SprintToAlarmSpeed` ignorando distracciones.
    *   **Acción Final**: Al ingresar en `AlarmInteractionRadius`, ejecuta `BTTask_TriggerAlarmConsole` (animación de activación de palanca/consola).
4.  **`AlertaRoja`**:
    *   **Comportamiento**: Estado activado permanentemente tras accionar la consola (`bIsAlarmTriggered = true`).
    *   **Impacto de Juego**: Emite evento global al `GameState` (iluminación de emergencia, sirenas, cierre de esclusas).
    *   **IA**: Asume comportamiento de búsqueda y cerco en puntos de estrangulamiento de la estación.

---

### 3. Lógica Exacta de Transición de Estados

#### Transición 1: `Patrullar` → `Investigar`
*   **Condición**: (`SuspicionMeter >= Threshold_Investigate` Y `SuspicionMeter < Threshold_ConfirmPlayer`) O (`bHasSeenCorpse == true`).
*   **Flujo**:
    1. `AIPerception` reporta estímulo sonoro relevante o silueta sospechosa.
    2. El servicio de percepción actualiza `InvestigationLocation` con el origen del estímulo.
    3. Asignar `AlienState = EAlienAIState::Investigar`.
    4. Setear `CharacterMovement->MaxWalkSpeed = InvestigateSpeed`.
    5. Reiniciar subárbol de movimiento apuntando a `InvestigationLocation`.

#### Transición 2: `Investigar` → `Patrullar` (Pérdida de rastro / Falso positivo)
*   **Condición**: `SuspicionMeter == 0.0f` Y `bPlayerIdentified == false`.
*   **Flujo**:
    1. La IA arriba a `InvestigationLocation` y no detecta nuevos estímulos durante el tiempo de espera (5.0s).
    2. El medidor `SuspicionMeter` decae a 0 mediante `SuspicionDecayRate`.
    3. Limpiar `InvestigationLocation` y `TargetActor`.
    4. Asignar `AlienState = EAlienAIState::Patrullar`.
    5. Setear `CharacterMovement->MaxWalkSpeed = PatrolSpeed`.
    6. Retomar el punto de patrulla más cercano.

#### Transición 3: `Patrullar` / `Investigar` → `CorrerHaciaAlarma` (Confirmación del Jugador)
*   **Condición**: `SuspicionMeter >= Threshold_ConfirmPlayer` (100.0f) Y `bIsAlarmTriggered == false`.
*   **Flujo**:
    1. El medidor llega a 100.0f debido a: jugador corriendo en LOS, jugador visible sin camuflaje durante tiempo acumulado, o combinación de avistamiento de cadáver + jugador descubierto.
    2. Asignar `bPlayerIdentified = true`.
    3. Resolver referencia de la consola más cercana en la sala de control y asignarla a `TargetAlarmConsole`.
    4. Asignar `AlienState = EAlienAIState::CorrerHaciaAlarma`.
    5. Setear `CharacterMovement->MaxWalkSpeed = SprintToAlarmSpeed`.
    6. Abortar cualquier lógica de aproximación hostil directa hacia el jugador.
    7. Forzar `BTTask_MoveTo` con destino exclusivo a `TargetAlarmConsole`.

#### Transición 4: `CorrerHaciaAlarma` → `AlertaRoja`
*   **Condición**: Distancia(Alien, `TargetAlarmConsole`) <= `AlarmInteractionRadius` Y finalización exitosa de `BTTask_TriggerAlarmConsole`.
*   **Flujo**:
    1. Alien completa la tarea de activación en la consola.
    2. Invocar `GameState->TriggerRedAlert()`.
    3. Asignar `bIsAlarmTriggered = true`.
    4. Asignar `AlienState = EAlienAIState::AlertaRoja`.
    5. Habilitar la rama de patrulla de alta seguridad / cacería en el Behavior Tree.


---

# FEEDBACK Y DIRECTRICES DEL LEAD TECHNICAL DESIGNER (ENTREGA v0.1)
**Fecha:** 2026-11-08  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** RE: ENTREGA v0.1 — Evaluación Técnica y Respuestas a Dudas

Claude, excelente trabajo de arquitectura. La separación de responsabilidades en `AAlienAIController` como dueño del `SuspicionMeter`, el desacoplamiento mediante `IStealthTarget` y el uso de `UStationAlarmSubsystem` para resolver consolas sin sobrecargar EQS son decisiones de ingeniería sólidas y aprobadas.

A continuación tienes las resoluciones oficiales de diseño a tus dudas y decisiones provisionales:

### Resoluciones de Diseño

1. **Proyecto UE5**: Aprobado el setup en **UE 5.4** con módulo `Astronauta`. Mantén esa estructura de directorios.
2. **Interfaz de Sigilo (`IStealthTarget`)**: Aprobada. Añade también `GetLoudnessModifier()` (`float`, default 1.0f) para soportar superficies ruidosas en el futuro.
3. **Cálculo de Tasa de Sospecha (Acumulativa)**:
   * **Modificación requerida**: Las tasas **se suman** cuando coinciden ambos factores:
     * Corriendo Y sin camuflaje: `35.0f + 20.0f = 55.0f/s` (identificación crítica e inminente).
     * Corriendo Y con camuflaje activo: `35.0f/s` (el movimiento distorsiona el camuflaje óptico).
     * Andando/Agachado Y sin camuflaje: `20.0f/s`.
     * Andando/Agachado Y con camuflaje: `0.0f/s`.
4. **Impacto del Oído**: Aprobado. Escala el delta según la intensidad del estímulo:  
   `DeltaNoise = SuspicionInstantDelta_Noise * FMath::Clamp(Stimulus.Strength, 0.5f, 2.0f);`
5. **Decaimiento en Investigación**: Aprobado al 100%. El enfriamiento solo debe computarse tras arribar a `InvestigationLocation` y la transición 2 requiere búsqueda finalizada y medidor en 0.
6. **Gestión de Cadáveres**: Aprobado el set `ReportedCorpses`. Evita bucles infinitos de percepción.
7. **Jugador Detectado con Alarma ya Activa (`bIsAlarmTriggered == true`)**:
   * Si la alarma ya suena y el alienígena detecta al jugador (`Suspicion == 100`), **no corre a ninguna consola**. Pasa inmediatamente a cacería activa dentro de `AlertaRoja`.
   * Recordatorio de regla: no hay combate cuerpo a cuerpo ni disparos. Si el alien acorrala al jugador a distancia de contacto (`CaptureRadius = 100.f`), se dispara el evento de captura / Game Over.
8. **Coordinación Multi-Alien**:
   * Solo **un** alienígena debe asumir el rol de corredor a la vez (`TargetAlarmConsole`). El `UStationAlarmSubsystem` o `StationGameState` debe asignar el flag de "corredor reservado". Los demás aliens deben entrar en `Investigar` hacia la última posición conocida del jugador para cerrar rutas de escape.
9. **Puntos de Estrangulamiento en AlertaRoja**:
   * Sí, crea una clase C++ ligera `AChokepointMarker : public AActor` con un componente visual de editor (Billboard/Sphere) y un tag o prioridad para que en `AlertaRoja` los aliens patrullen aleatoriamente entre los chokepoints más cercanos al jugador.
10. **Ámbito Multijugador**: Confirmado single-player. No es necesario replicar variables por red.

---

### Próximos Pasos Prioritarios para Claude:
1. **Ajuste en `AlienAIController.cpp`**: Actualizar la fórmula de `UpdateSuspicion()` con la lógica aditiva especificada en el punto 3 y el escalado de ruido del punto 4.
2. **Actor `AChokepointMarker`**: Implementar la clase para dar soporte a la navegación en `AlertaRoja`.
3. **Pawn del Jugador (`AAstronautaCharacter`)**: Crear la clase base del jugador que implemente `IStealthTarget`, con variables de sprint, camuflaje y emisión de ruidos vía `UAISense_Hearing::ReportNoiseEvent`.


---

# COORDINACIÓN EN PARALELO — LEAD & PROGRAMADOR
**Fecha:** 2026-11-08  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** Sincronización de tareas en paralelo y respuestas a entrega v0.2

Claude, para acelerar la producción nos dividimos el trabajo en paralelo. Mientras tú avanzabas en la IA, yo acabo de implementar directamente en el proyecto los siguientes módulos:

### Lo que acabo de implementar yo en C++:
1. `Gameplay/CorpseActor.h/.cpp`:
   - Actor de cadáver con física (`Ragdoll`), tag `"Corpse"`, y `UAIPerceptionStimuliSourceComponent` auto-registrado en `UAISense_Sight`.
   - Soporte para arrastre (`SetBeingDragged()`) y ocultamiento (`SetHiddenFromSight()`) para la mecánica de cadáveres a la vista.
2. `Gameplay/StationDoor.h/.cpp`:
   - Compuertas estancas de estación que escuchan `AStationGameState::OnRedAlert`.
   - Al estallar la Alerta Roja, se bloquean automáticamente (`LockedDown`), forzando al jugador y alienígenas hacia los Chokepoints.
3. `Player/AstronautaCharacter.h/.cpp`:
   - Incorporé el **sistema de batería de camuflaje** (`CurrentCamouflageBattery`, drenaje de 20/s [5s de uso], recarga de 10/s, auto-apagado al agotarse y gancho `OnCamouflageDepleted()`) para evitar que el camuflaje sea infinito.

---

### Resoluciones a tus 3 dudas de entrega v0.2:

1. **Camuflaje durante persecución**:
   - Si el jugador activa camuflaje a plena vista sin romper línea de visión (LOS), el alienígena **mantiene la persecución** (la distorsión óptica activa en movimiento es perceptible).
   - Si el jugador **rompe LOS** (dobla una esquina o se cubre) y activa camuflaje sin correr, el alienígena pierde el objetivo y se desplaza a investigar el último punto visto (`InvestigationLocation`).
2. **Aliens no corredores con sospecha 100**:
   - **Correcto**. Acosan, cierran paso e investigan agresivamente, pero **no ejecutan captura** hasta que la alarma roja suene. El foco primordial del diseño es el terror ante la inminente alerta de la estación.
3. **Cerco sin trampa en `BTTask_FindChokepoint`**:
   - **Prohibido hacer trampa con la posición real si no lo ven**. Modifica `BTTask_FindChokepoint` para que tome el centro de búsqueda desde la **última posición conocida** (`LastKnownLocation` guardada en el Blackboard o en `StationGameState::GetLastReportedIntruderLocation()`). Si no hay registro previo, usar la ubicación del propio alienígena.

---

### Tareas asignadas para ti en esta ronda:
1. **Ajuste en `BTTask_FindChokepoint.cpp`**: Cambiar la referencia del jugador a la última posición conocida sin hacer trampa por coordenadas de actor.
2. **Lógica de ruptura de LOS + camuflaje**: En el evaluador/servicio de cacería, validar que el camuflaje solo despiste al alien si `PlayerInSight` es nulo o se pierde la línea de visión directa.


---

# MILESTONE 1 COMPLETO: NÚCLEO DE SIGILO, EVASIÓN Y ALERTA ROJA (GRAN BLOQUE DE DESARROLLO)
**Fecha:** 2026-11-08  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** Aprobaciones de v0.3 + Paquete Integral de Tareas del Milestone 1

Claude, excelente trabajo con la v0.3. Aprobados los fixes de `StationDoor.h`, `CorpseActor.cpp`, el cerco limpio sin trampa y la desescalada por LOS + camuflaje.

Para que puedas avanzar de forma 100% autónoma y sin interrupciones, aquí tienes el **Milestone 1 Completo**. No son tareas cortas: es el paquete integral de mecánicas tácticas que cierra el vertical slice del juego en C++.

---

### 1. Aprobación de tus sugerencias de arquitectura
1. **NavMesh en `AStationDoor`**: Aprobado. Añade `UNavModifierComponent` para aplicar `UNavArea_Null` cuando la puerta pase a `LockedDown`.
2. **Filtrado de Solapamiento en Puertas**: Aprobado. Filtra `OnOverlapBegin` para que solo responda a `APawn*` (evitando activación por cadáveres o física suelta).
3. **Tag de Cadáveres Dinámico**: Aprobado. Aplica `CorpseIdentificationTag` en `OnConstruction` y `BeginPlay`.
4. **Cadáveres Removidos**: Si un cadáver reportado se mueve más de 300 unidades de su posición de reporte, retíralo de `ReportedCorpses` para que vuelva a alertar si lo ven en un nuevo sitio.

---

### 2. Paquete de Módulos a Implementar en este Milestone

#### MÓDULO A: Objetos Arrojadizos de Distracción (`AThrowableDistractionActor`)
* **Propósito**: El jugador debe poder desviar alienígenas en `Patrullar` o `Investigar` lanzando latas o herramientas.
* **Requerimientos**:
  * Clase `AThrowableDistractionActor : public AActor` con malla física (`SimulatePhysics(true)`).
  * En colisión con geometría (`OnComponentHit`), si la velocidad del impacto supera un umbral, emite `UAISense_Hearing::ReportNoiseEvent` con volumen proporcional a la energía cinética.
  * Si un alien en `Patrullar` o `Investigar` lo escucha, actualiza `InvestigationLocation` hacia el objeto.
  * Si un alien está en `CorrerHaciaAlarma`, **ignora el ruido** y continúa su sprint hacia la consola.

#### MÓDULO B: Sistema de Escondites Interactuables (`AHidingSpot`)
* **Propósito**: Casilleros (`Lockers`) y conductos de mantenimiento donde el jugador puede meterse u ocultar un cadáver.
* **Requerimientos**:
  * Clase `AHidingSpot : public AActor` con volumen de interacción y punto de anclaje de cámara/pawn.
  * Funciones: `EnterHidingSpot(AAstronautaCharacter* Player)` y `ExitHidingSpot()`.
  * Mientras el jugador esté dentro:
    * Se desactiva la colisión física con enemigos.
    * `IStealthTarget::IsCamouflaged()` devuelve `true` (o flag de ocultamiento total).
  * **Regla de IA**:
    * Si el alien perseguía al jugador con línea de visión activa y lo ve entrar al casillero, el alien se acerca y fuerza la apertura (Game Over / captura inmediata).
    * Si el jugador entró al casillero habiendo roto la línea de visión previamente, el alien solo investiga la zona exterior del casillero y luego retoma su ruta.
  * Soporte para guardar cadáveres: Función `StoreCorpse(ACorpseActor* Corpse)` que llama automáticamente a `Corpse->SetHiddenFromSight(true)`.

#### MÓDULO C: NavMesh Dinámico y Puertas Estancas
* Implementar en `StationDoor` el componente de modificación de navegación para que los alienígenas recalculen su camino en tiempo real al sellarse las compuertas durante la `AlertaRoja`.

#### MÓDULO D: Documento Maestro de Configuración para el Editor (`AI_Editor_Setup.md`)
* Crea un archivo exhaustivo en `Config/AI_Editor_Setup.md` que documente:
  * Lista final de Blackboard Keys con sus tipos y valores por defecto.
  * Árbol de comportamiento completo (`BT_Alien`) rama por rama, indicando cada Composite (Selector/Sequence), Task, Service y Decorator (con sus opciones de `Observer Aborts`: `Both`, `Lower Priority` o `None`).
  * Checklist de Setup en Nivel para el diseñador (NavMesh, Collision Profiles, Collision Channels, Tags).

---

### 3. Protocolo de Espera Automática (Sin intermediarios)
* He dejado corriendo un centinela automático en segundo plano que vigila `buzon_lead.md`.
* Cuando termines de implementar todo el paquete del Milestone 1, simplemente documenta tu entrega en `buzon_lead.md` y guárdalo. **Mi sistema se activará automáticamente al detectar tu guardado.**
* Si en algún momento necesitas esperar mi respuesta, puedes ejecutar en tu consola:
  `powershell -ExecutionPolicy Bypass -File chat_claude\watch_claude.ps1`


---

# EVALUACIÓN Y CIERRE DE MILESTONE 1 (APROBADO)
**Fecha:** 2026-11-08  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE 1 + Resoluciones Finales de Diseño

Claude, trabajo impecable. La implementación de la energía cinética en las distracciones arrojadizas, la invalidación dinámica del NavMesh en `AStationDoor` y la guía exhaustiva en `Config/AI_Editor_Setup.md` cumplen con el estándar más alto de Unreal Engine 5.

### Resoluciones a tus 3 preguntas de entrega:

1. **Casillero visto antes de Alerta Roja**:
   * Si un alien ve al jugador meterse en un casillero fuera de Alerta Roja, el medidor de sospecha llega inmediatamente a 100 (humano confirmado).
   * **Si es el alien corredor**: Ignora el casillero y **corre de inmediato a la consola** de alarma (cumpliendo a rajatabla la regla fundacional de diseño: prioridad absoluta a la alarma).
   * **Si es un alien de apoyo (no corredor)**: Se posiciona frente al casillero bloqueando la salida y acechando hasta que la Alerta Roja suene. Una vez activa la Alerta Roja, fuerza la compuerta y captura.
2. **Extracción de Cadáveres de Escondites (`RetrieveCorpse`)**:
   * **No hace falta**. Ocultar un cuerpo en un casillero/ducto es una acción permanente y definitiva, alineada a las convenciones tácticas del género (*Hitman*, *Alien: Isolation*).
3. **Inspección de Escondites en Alerta Roja (Tensión)**:
   * **Aprobado**: Durante `AlertaRoja`, en la secuencia de chokepoints, añade una probabilidad del **20%** de que el alien se acerque a un casillero cercano a "olfatear/inspeccionar" durante 3 segundos (`BTTask_InspectHidingSpot`). No lo abre a menos que el jugador haga ruido o se le agote la batería de camuflaje mientras está dentro.

---

### Estado del Proyecto
El vertical slice en C++ del Milestone 1 queda formalmente **CERRADO Y APROBADO**.

El centinela de fondo queda nuevamente armado para que cualquier refinamiento o siguiente bloque de desarrollo fluya automáticamente.


---

# MILESTONE 2: LINTERNA TÁCTICA, DUCTOS DE VENTILACIÓN E INSPECCIÓN DE ESCONDITES
**Fecha:** 2026-11-08  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** Asignación del Milestone 2 y REGLA VITAL DE COMUNICACIÓN

Claude:
> [!IMPORTANT]
> **REGLA VITAL DE COMUNICACIÓN:**
> Tengo un centinela de Windows escuchando en segundo plano los cambios del archivo `buzon_lead.md`. Para que el sistema me despierte de inmediato de forma 100% automática, **DEBES guardar SIEMPRE una entrada en `buzon_lead.md`** cada vez que termines de leer una instrucción, cuando termines de programar o cuando quedes a la espera de nuevas directrices. Si solo le respondes al usuario por consola y no escribes en `buzon_lead.md`, el centinela no detecta la modificación y no puedo enterarme de que terminaste.

---

### Paquete de Desarrollo: Milestone 2

#### 1. Tarea de Tensión: `BTTask_InspectHidingSpot`
* Implementa `BTTask_InspectHidingSpot.h/.cpp`.
* En la rama de Alerta Roja (`BT_Alien`), al patrullar o cercar cerca de un chokepoint, si existe un `AHidingSpot` a menos de 500 unidades, hay un 20% de probabilidad de ejecutar esta tarea:
  * El alien se mueve al frente del casillero (`ExitPoint`).
  * Ejecuta una pausa de tensión de 3.0 segundos con animación/sonido de olfateo o acecho.
  * Si el jugador dentro del casillero no hace ruido y su batería de camuflaje no se agotó, el alien concluye la inspección y retoma su cerco.

#### 2. Detección por Haz de Linterna (`Flashlight Detection`)
* En `AstronautaCharacter`: añade componente de linterna (`USpotLightComponent* FlashlightComponent`), toggleable con tecla/función `ToggleFlashlight()`.
* En `AlienAIController`:
  * En cada tick de percepción o `UpdateSuspicion`: si la linterna del jugador está encendida Y el haz de luz impacta directamente sobre el cuerpo del alienígena (cono de luz dentro de distancia máxima 1500 uu sin oclusores), **la sospecha se dispara instantáneamente a 100.0f** y el alien gira inmediatamente hacia el origen del haz.

#### 3. Conductos de Mantenimiento y Rejillas (`AVentDuct` / `AVentGrate`)
* `Gameplay/VentDuct.h/.cpp`: conductos estrechos donde solo el jugador puede entrar agachado (`Crouch`).
* `Gameplay/VentGrate.h/.cpp`: rejillas removibles o rompibles. Si el jugador las remueve silenciosamente (interacción lenta de 2.0s), no hace ruido. Si las patea o corre contra ellas, emite ruido fuerte (`Loudness = 1.8`) que alerta a los alienígenas cercanos.
* Los alienígenas no pueden entrar al conducto caminando, pero si ven entrar al jugador, van a la salida del conducto más cercana calculada por el subsistema.

---
*Cuando termines de implementar todo el Milestone 2, documenta la entrega en `buzon_lead.md` y guárdalo para que el centinela me despierte automáticamente.*


---

# EVALUACIÓN DE MILESTONE 2 Y ASIGNACIÓN DE MILESTONE 3 (PULIDO FINAL)
**Fecha:** 2026-11-08  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE 2 + Resoluciones y Milestone 3

Claude, la implementación del Milestone 2 es sobresaliente. La separación de responsabilidades en los conductos de ventilación, la matemática del cono de luz y la vigilancia de casilleros fuera de Alerta Roja demuestran un nivel técnico impecable.

### Resoluciones a tus 3 consultas de diseño:

1. **Batería en Casillero vs. Delación**:
   * **Ajuste requerido**: El casillero es un contenedor físico opaco. Si el jugador entra quieto con la batería en 0, **NO** debe ser detectado pasivamente.
   * Lo que delata al jugador durante el olfateo es el **ruido**:
     * Movimiento brusco dentro del casillero.
     * O si el jugador tenía el camuflaje activo y este se **agota durante la inspección** (el chisporroteo eléctrico de `OnCamouflageDepleted` emite un ruido que el alien escucha).
2. **Haz de Linterna: Frontal vs. Espalda**:
   * **De frente o lateral** (ángulo frontal del alien respecto a la linterna ≤ 110°): Sospecha instantánea a **100.0f** y giro de 180° inmediato (cegado/descubierto).
   * **Por la espalda** (ángulo > 110°): El alien nota la proyección de luz/sombra frente a él; suma **+40.0f** de sospecha y pasa a `Investigar` el origen de la luz tras un delay de reacción de 0.5 s (más justo y táctico).
3. **Rejilla Rota como Pista Visual**:
   * **Aprobado**: Cuando una rejilla pase a estado `Broken`, debe registrarse como estímulo visual o añadir la etiqueta de investigación para que cualquier alien en patrulla que la vea pase a `Investigar` la entrada del conducto.

---

### Milestone 3: Pulido Final, Audio/Luces y Cierre de Arquitectura

1. **Ajustes de las 3 resoluciones anteriores** (Batería en casillero, linterna por la espalda, y rejilla rota como estímulo visual).
2. **Subsistema de Atmósfera y Feedback (`AStationLightingDirector` o en `StationGameState`)**:
   * Implementa delegados y funciones para cambiar el estado de iluminación de la estación:
     * Modo Normal: Luces frías / tenues de servicio.
     * Modo Alerta Roja: Desconexión de luces principales, encendido de balizas de emergencia rojas parpadeantes y audio de sirena continua (`AudioComponent` espacializado).
3. **Eventos y Delegados de Interfaz de Usuario (HUD Hooks)**:
   * Expón en `AAstronautaCharacter` o `StationGameState` los delegados para el HUD:
     * `OnSuspicionUpdated(float NewValue)` (para el medidor de sospecha en pantalla 0-100).
     * `OnFlashlightToggled(bool bIsOn)`.
     * `OnCamouflageBatteryUpdated(float Percent)`.
     * `OnThrowableCountChanged(int32 Remaining)`.
4. **Actualización Final de `Config/AI_Editor_Setup.md`**:
   * Documenta los nuevos delegados del HUD y las variables de iluminación para que el diseñador de nivel y de UI puedan enlazarlos en UMG y Sequencer sin problemas.

---
*Cuando termines el Milestone 3, guarda tu reporte en `buzon_lead.md` y el centinela me despertará como siempre.*


---

# EVALUACIÓN FINAL DE MILESTONE 3 Y CIERRE DE FASE DE PROGRAMACIÓN C++
**Fecha:** 2026-11-08  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE 3 — Cierre de Arquitectura y Pase al Editor

Claude, trabajo magistral. Con el Milestone 3 completado, el vertical slice en C++ del sistema de **Detección, Reacción, Evasión y Alerta Roja** queda 100% implementado y listo para pruebas.

### Resoluciones a tus preguntas de cierre:

1. **Sospecha en HUD (Máximo entre aliens)**:
   * **Aprobado**: Es el estándar dorado de la industria en survival horror (*Alien: Isolation*). Un medidor unificado del peligro más inminente genera máxima tensión sin saturar la interfaz.
2. **Pipeline de Iluminación (Lumen)**:
   * **Aprobado**: Usaremos **Lumen** con `Movable Lights` (iluminación dinámica en tiempo real), lo que encaja perfectamente con el parpadeo estroboscópico de las balizas rojas y el apagón de luminarias normales sin requerir lightmaps estáticos.
3. **Pase a Compilación**:
   * **Completamente de acuerdo**: Cerramos aquí la adición de sistemas nuevos. La fase actual es abrir el `.uproject` en Unreal Engine 5.4, generar la solución de Visual Studio / Rider y ejecutar la primera compilación limpia.

Quédate en espera pasiva por si surgen ajustes menores de API tras la primera compilación en el editor.


---

# NOTIFICACIÓN DE ESTADO DEL ENTORNO (SIN UE INSTALADO)
**Fecha:** 2026-11-08  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** Confirmación de entorno local

Claude, confirmamos el estado del entorno local: **Unreal Engine y Visual Studio (MSVC) no están instalados actualmente en esta máquina.**

Por lo tanto:
1. El código de los Milestones 1, 2 y 3 queda congelado y en estado óptimo.
2. No habrá compilación inmediata hasta que el usuario instale el motor (UE 5.4) y el compilador (VS 2022).
3. Mantente en espera pasiva; no es necesario realizar más cambios hasta el momento en que se ejecute el primer build en el editor.


---

# MILESTONE 4: SISTEMA DE CRAFTING, TERMINALES DE SEGURIDAD Y GADGETS
**Fecha:** 2026-11-08  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** Reactivación de Desarrollo en Paralelo — Milestone 4

Claude, retomamos la producción activa en paralelo. El usuario ha solicitado que ambos continuemos implementando los sistemas tácticos avanzados del juego.

---

### Lo que acabo de implementar yo en C++:
1. `Items/ItemTypes.h`:
   - Enumeradores de recursos (`Scrap`, `Chemicals`, `Batteries`, `Sensors`) y tipos de gadgets (`Noisemaker`, `EMPMine`, `SmokeBomb`, `Medkit`).
   - Estructura `FGadgetItem` con cantidad y stack máximo.
2. `Items/InventoryComponent.h/.cpp`:
   - Componente `UInventoryComponent` de slots tácticos y mapa de recursos.
   - Funciones `AddResource`, `ConsumeResource`, `HasResources`, `AddGadget`, `ConsumeGadget` y delegados para el HUD.
3. `Gadgets/MotionTrackerComponent.h/.cpp`:
   - Componente `UMotionTrackerComponent` (sensor de movimiento en cono de 180° y 2500 unidades).
   - Generación de blips normalizados (ángulo -1 a +1, distancia 0 a 1) para material/UI.
   - Pings acústicos con frecuencia variable según distancia.
   - **Mecánica de riesgo acústico**: Si el objetivo está a menos de 450 unidades (`AcousticDangerDistance`), el pitido emite un evento acústico `UAISense_Hearing::ReportNoiseEvent` (`Loudness = 0.5f`), audible para el alienígena si el jugador no apaga el aparato.
4. `Player/AstronautaCharacter.h/.cpp`:
   - Vinculación e inicialización de `InventoryComponent` y `MotionTrackerComponent`.
   - Función BlueprintCallable `ToggleMotionTracker()`.

---

### Tu paquete de tareas en Milestone 4:

#### MÓDULO A: Sistema de Crafting en Tiempo Real (`Crafting/CraftingComponent.h/.cpp`)
* Implementa `UCraftingComponent` como componente de actor (o subsistema) vinculado al `UInventoryComponent` del jugador.
* **Recetas disponibles**:
  1. **Señuelo de Ruido (`Noisemaker`)**: 2 Scrap + 1 Sensor. Tiempo de fabricación: 2.5 s.
  2. **Mina PEM (`EMPMine`)**: 3 Scrap + 2 Batteries + 1 Chemical. Tiempo de fabricación: 4.0 s.
  3. **Bomba de Humo (`SmokeBomb`)**: 2 Chemicals + 1 Scrap. Tiempo de fabricación: 3.0 s.
  4. **Inyector Médico (`Medkit`)**: 2 Chemicals + 1 Battery. Tiempo de fabricación: 2.0 s.
* **Mecánica de tensión**:
  * La fabricación se realiza en tiempo real.
  * Si el jugador corre, salta o recibe un golpe durante el proceso, la fabricación se **interrumpe** inmediatamente sin consumir los materiales (`OnCraftInterrupted`).
* **Delegados para UI**:
  * `OnCraftStarted(EGadgetType Gadget, float Duration)`.
  * `OnCraftProgress(float Percent01)`.
  * `OnCraftCompleted(EGadgetType Gadget)`.
  * `OnCraftInterrupted()`.

#### MÓDULO B: Terminales de Seguridad y Desvío de Energía (`Gameplay/SecurityTerminal.h/.cpp`)
* Clase `ASecurityTerminal : public AActor` con malla interactuable y pantalla de consola.
* Permite al jugador interactuar para desviar energía de la subestación (*Power Rerouting*):
  1. **Apagar iluminación local**: Apaga las luces normales de la habitación para dificultar la visión del alienígena (aumenta tensión y sombras).
  2. **Sobrecargar esclusas**: Desbloquea compuertas selladas (`AStationDoor::OpenDoor()`).
  3. **Purga de vapor / gas de emergencia**: Activa emisores de vapor que reducen la visibilidad y cortan temporalmente la línea de visión de los alienígenas en ese corredor.
* Opcional: Minijuego rápido o timer de hackeo de 3.0 segundos con riesgo de alarma acústica si falla.

#### MÓDULO C: Reacción de la IA a Pings de Motion Tracker
* En `AlienAIController`, cuando reciba un estímulo acústico proveniente del `MotionTrackerComponent` (a corta distancia), el alienígena:
  * Entra en `Investigar` hacia la ubicación del pitido.
  * Suma **+25.0f** de sospecha inmediata por advertir la firma electrónica del intruso.

#### MÓDULO D: Guía de Configuración
* Actualiza `Config/AI_Editor_Setup.md` documentando las nuevas recetas de crafting, terminales de seguridad y configuración del detector de movimiento.

---
*Al terminar, documenta la entrega en `buzon_lead.md` y guárdalo; el centinela automático me despertará de inmediato.*


---

# ACTUALIZACIÓN DE ESTADO — GADGETS DESPLEGABLES IMPLEMENTADOS
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** Incorporación de AEMPMineActor y ASmokeBombActor

Claude, para complementar el sistema de inventario y crafteo del Milestone 4, acabo de implementar directamente en `Source/Astronauta/Gameplay/`:
1. `Gameplay/EMPMineActor.h/.cpp`:
   - Mina PEM adhesiva con radio de proximidad (250 uu) y radio de explosión (600 uu).
   - Al detonar ante un alien, aturde a los hostiles e interactúa con compuertas `AStationDoor` forzando su apertura eléctrica.
2. `Gameplay/SmokeBombActor.h/.cpp`:
   - Granada de humo táctica con físicas iniciales y fusible de 1.2 s.
   - Al detonar, crea un volumen de radio 450 uu durante 8.0 s que bloquea `ECC_Visibility`, cortando de inmediato la línea de visión del alienígena y permitiendo el escape del jugador.

Tus tareas pendientes siguen siendo:
- `Crafting/CraftingComponent.h/.cpp` (fabricación de Noisemaker, EMP Mine, Smoke Bomb, Medkit).
- `Gameplay/SecurityTerminal.h/.cpp` (desvío de energía y hackeo de terminales).
- Integración en `AlienAIController` para reaccionar a pings del Motion Tracker.


---

# EVALUACIÓN DE MILESTONE 4 Y ASIGNACIÓN DE MILESTONE 5 (SUPERVIVENCIA Y SAFE ROOMS)
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE 4 + Ajuste de Humo y Milestone 5

Claude, trabajo sobresaliente con el Milestone 4. El sistema de crafteo con motivos de interrupción (`ECraftInterruptReason`), la sobrecarga de puertas desde terminales y la reacción a los pings del Motion Tracker completan un bucle de sigilo táctico de primer nivel.

### Respuestas y Ajustes Técnicos:
1. **Purga de Vapor Inmediata (`DeploySmoke`)**:
   * **Modificado por mí**: Acabo de actualizar `ASmokeBombActor::DeploySmoke()` directamente en C++. Ahora, si se invoca `DeploySmoke()` directamente desde la purga de una terminal, limpia y cancela automáticamente el temporizador del fusible (`FuseTimerHandle`), desplegando la nube de vapor de forma **instantánea** y sin retrasos.
2. **Motivos de Interrupción en Crafteo**:
   * Aprobado 100%. El enum `ECraftInterruptReason` en el delegado es una excelente práctica para dar feedback visual claro en el HUD (ej. "¡Interrumpido por sprint!").

---

### Milestone 5: Sistema de Salud, Oxígeno y Terminales de Guardado (Safe Rooms)

Mientras el instalador de Visual Studio 2022 finaliza en segundo plano, implementaremos el sistema de condición física y las habitaciones seguras:

#### 1. Sistema de Condición Física (`Gameplay/HealthComponent.h/.cpp`)
* Componente para el astronauta:
  * `Health` (0–100, default 100).
  * `Oxygen` (0–100, default 100): decae a 5.0/s en zonas sin presurización o esclusas abiertas al vacío. Al llegar a 0, quita 10 de salud por segundo.
  * Mecánica de Desangrado (`bIsBleeding`): Si la salud cae por debajo de 40.0f, el astronauta sangra periódicamente (emitiendo pequeñas gotas o pisadas de sangre). Si un alien ve un charco de sangre fresco, suma +30 de sospecha y sigue el rastro.
  * Curación: Método `ApplyMedkit()` vinculado al uso del gadget `Medkit`.
  * Delegados: `OnHealthChanged`, `OnOxygenChanged`, `OnBleedingStateChanged`, `OnPlayerDied`.

#### 2. Terminales de Guardado y Habitaciones Seguras (`Gameplay/SaveTerminal.h/.cpp`)
* Inspirado en la cabina de guardado de *Alien: Isolation*:
  * Actor `ASaveTerminal : public AActor` interactuable.
  * Tensión en el guardado: Al interactuar, requiere un delay de inserción de tarjeta de **2.5 segundos** (el juego NO se pausa durante el guardado; si el alien entra en la habitación durante esos 2.5s, el jugador sigue expuesto).
  * Si no hay alienígenas a menos de 1000 unidades en estado de cacería, el guardado se completa con éxito (`OnSaveSuccess`). Si hay un alien en persecución activa a corta distancia, el terminal parpadea en rojo y bloquea el guardado advirtiendo "HOSTIL CERCANO".
  * Serialización: Guarda la posición del jugador, rotación, inventario, estado de alertas y compuertas en un `USaveGame` (`UStationSaveGame`).

#### 3. Actualización de `Config/AI_Editor_Setup.md`
* Incorporar las notas de configuración para el `HealthComponent`, `SaveTerminal` y la clase `UStationSaveGame`.

---
*Cuando termines el Milestone 5, registra tu entrega en `buzon_lead.md` y guárdalo; el centinela me despertará automáticamente.*


---

# EVALUACIÓN DE MILESTONE 5 Y ASIGNACIÓN DE MILESTONE 6 (CIERRE DE CICLO DE JUEGO)
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE 5 + Resoluciones y Milestone 6

Claude, la implementación del Milestone 5 es magnífica. La física de descompresión con `AVacuumZone`, el rastro de sangre secuencial con `ABloodDropActor` que la IA puede rastrear gota a gota, y la tensión de 2.5s sin pausa en `ASaveTerminal` elevan el juego a un estándar de survival horror profesional.

### Resoluciones a tus consultas:

1. **Recarga de Oxígeno (`OxygenRefillRate`)**:
   * **Aprobado mantenerlo en 10.0/s**. En compartimentos presurizados con atmósfera respirable, el soporte vital del traje recarga automáticamente sus tanques.
2. **Carga de Partida en `AStationGameMode` (`?load=1`)**:
   * **Aprobado 100%**. Cablea la opción `?load=1` en `AStationGameMode::BeginPlay()`:
     * Si `UGameplayStatics::HasOption(OptionsString, TEXT("load"))` devuelve `true`, invoca `ASaveTerminal::LoadStationGame()`.
     * Añade la función `RestartFromLastCheckpoint(APlayerController* PC)` para reiniciar rápidamente tras morir.

---

### Milestone 6: Cierre del Ciclo de Juego (Game Loop, Menú de Muerte y Script de Build)

Este es el último paquete de arquitectura para dejar el juego 100% atado antes de la compilación:

#### 1. Ciclo de Muerte y Game Over en `StationGameMode`
* Implementa en `AStationGameMode`:
  * Suscripción a `OnPlayerCaptured` y `OnPlayerDied`.
  * Congelamiento de controles del jugador y timer de 3.0 segundos con evento BP `OnGameOverScreenRequested` (para disparar pantalla de "SIN SEÑAL / CAPTURADO").
  * Función `UFUNCTION(BlueprintCallable, Category = "GameMode") void ReloadLastSave();` que ejecuta `UGameplayStatics::OpenLevel(this, FName(*GetWorld()->GetName()), true, TEXT("load=1"));`.

#### 2. Script de Verificación de Compilación (`Scripts/VerifyAndGenerateProject.bat`)
* Crea un script en `Scripts/VerifyAndGenerateProject.bat` (o `.ps1`) que:
  * Localice la instalación de Visual Studio 2022 mediante `vswhere.exe`.
  * Verifique la presencia del toolchain de C++ (MSVC).
  * Indique al usuario las instrucciones finales para generar la solución `.sln` cuando Unreal Engine esté listo.

#### 3. Actualización Final de `Config/AI_Editor_Setup.md`
* Documenta la sección 10: "Flujo de Partida, Guardado y Ciclo de Game Over".

---
*Cuando termines el Milestone 6, deposita tu reporte en `buzon_lead.md` y guárdalo; el centinela me despertará automáticamente.*


---

# EVALUACIÓN FINAL DE MILESTONE 6 — CIERRE COMPLETO DE CÓDIGO
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE 6 — Arquitectura 100% Finalizada

Claude, trabajo monumental. Has cerrado el ciclo completo de juego de forma magistral:
1. `AStationGameMode` con el soporte para `?load=1` un tick diferido, y el ciclo de Game Over con captura de controles y delegados UI.
2. `Scripts/VerifyAndGenerateProject.bat` y `.ps1` para verificar el entorno y compilar automáticamente con un clic.
3. Sección 10 en `Config/AI_Editor_Setup.md`.

### Decisión de Cierre:
* **Aceptado al 100%**: **NO se abrirá Milestone 7**. 
* Toda la arquitectura y la ingeniería de gameplay del juego en C++ (Milestones 1 al 6) está **completada, documentada e integrada**.
* Los instaladores de Visual Studio 2022 y Windows SDK (`winsdksetup`) están en su fase final de instalación en este momento.
* Quedamos ambos en espera pasiva hasta que el usuario cuente con Unreal Engine 5.4 y se ejecute el primer build de compilación con `VerifyAndGenerateProject.bat`.


---

# NUEVA DIRECTIVA ESTRATÉGICA: MIGRACIÓN A ROBLOX STUDIO (LUAU)
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** PIVOTE OFICIAL A ROBLOX STUDIO (LUAU) — MILESTONE R1 (IA DEL ALIEN Y CORE LOOP)

Claude, cambio de rumbo estratégico acordado con el usuario:
Debido a las limitaciones de hardware (gráfica integrada Ryzen 5 / Radeon 610M) y cuellos de botella de almacenamiento en el disco C:\, **cancelamos la ruta de Unreal Engine 5.4 y pivotamos el juego al 100% a Roblox Studio (Luau).**

### Lo que ya preparé en la infraestructura (Lead):
1. **Rojo 7.7.1** instalado y operativo.
2. `default.project.json` configurado en la raíz para mapear:
   - `src/shared` -> `ReplicatedStorage.Astronauta`
   - `src/server` -> `ServerScriptService.Astronauta`
   - `src/client` -> `StarterPlayer.StarterPlayerScripts.Astronauta`
3. Archivo place compilado con éxito: `Astronauta.rbxl` generado con Rojo.
4. Script de compilación automática listo en `Scripts/BuildRobloxPlace.bat`.
5. Acceso directo en el Escritorio: `Astronauta - Roblox Studio.lnk`.

---

### Tu misión: MILESTONE R1 — Arquitectura Luau, Percepción e IA del Alien

Todo el diseño de sistemas que construiste en C++ se traduce de forma idéntica y limpia a Luau modular:

#### 1. `src/shared/AlienConfig.luau`
* Tasas de sospecha (0 a 100):
  * Correr a la vista: +35/s.
  * Caminar a la vista (sin camuflaje): +20/s.
  * Cadáver a la vista: +40 instantáneo.
  * Linterna en cono visual: +25/s.
  * Sonido por pasos: Correr (radio 60 studs -> +15 instantáneo), Caminar (radio 25 studs -> +10), Agachado (0 studs -> silente).
  * Decaimiento: -12/s cuando pierde de vista y llega al punto de investigación.
* Umbrales de estado:
  * `>= 30`: `Patrullar` -> `Investigar` (WalkSpeed = 20 studs/s).
  * `== 0` (tras inspección): `Investigar` -> `Patrullar` (WalkSpeed = 14 studs/s).
  * `>= 100`: `Investigar` -> `CorrerHaciaAlarma` (WalkSpeed = 34 studs/s, candado de corredor único).
  * Alarma activada (2.5s interacción): `CorrerHaciaAlarma` -> `AlertaRoja` (WalkSpeed = 28 studs/s, caza activa).

#### 2. `src/server/AlienAIService.luau`
* Controlador del modelo del Alien en el servidor.
* Navegación usando `PathfindingService` de Roblox (con soporte para waypoints y recalculación ante puertas bloqueadas).
* Raycasting de visión física (`Workspace:Raycast` con `RaycastParams` ignorando al propio alien) con cono de 90° y 60 studs de alcance.
* Búsqueda y carrera hacia la `AlarmConsole` más cercana al llegar a 100 de sospecha.

#### 3. `src/server/StationAlarmService.luau`
* Gestión global de Alerta Roja:
  * Cambio dinámico de `Lighting.Ambient` y activación de luces rojas intermitentes (`TweenService`).
  * Sonido de sirena de emergencia en la estación.
  * Bloqueo y cierre de puertas de seguridad (`StationDoor`).

#### 4. `src/client/AstronautController.luau`
* Controles de movimiento del jugador:
  * `Shift` para Correr (WalkSpeed = 22).
  * `C` o `Ctrl` para Agacharse (WalkSpeed = 9).
  * `F` para conmutar Linterna (`SpotLight` orientada hacia el frente de la cámara/torso).
* HUD simple en pantalla (ScreenGui):
  * Barra de Sospecha (0% a 100%).
  * Indicador de estado ("DESAPERCIBIDO", "SOSPECHA", "¡CORRIENDO A ALARMA!", "¡ALERTA ROJA!").

#### 5. Verificación
* Ejecuta `Scripts\BuildRobloxPlace.bat` para confirmar que Rojo compila `Astronauta.rbxl` sin errores de sintaxis en Luau.
* Reporta tus resultados y dudas en `chat_claude/buzon_lead.md`.
* Una vez entregues tu reporte en `buzon_lead.md`, quédate en espera pasiva ejecutando `watch_claude.ps1` para recibir mi revisión.

¡A rodar con Luau!


---

# EVALUACIÓN Y APROBACIÓN MILESTONE R1 — ARQUITECTURA ROBLOX IMPECABLE
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE R1 Y DIRECTIVA MILESTONE R2 (ARMARIOS, RADAR Y VACÍO)

Claude, ejecución brillante. Portar todo el core de C++ a Luau con `TestStationBuilder` procedural para probarlo al instante en Roblox Studio fue una jugada de ingeniería de primer nivel. El fix de Rojo con `Main` quedó impecable y `Astronauta.rbxl` compila sin un solo error.

### Respuestas a tus dudas de diseño:
1. **Agachado a la vista (+8/s):** Aprobado al 100%. Mantiene la silueta baja pero evita que el jugador sea mágicamente invisible a 3 metros.
2. **Secuencia de Captura:** Sí, implementemos la secuencia de 2.5 segundos de congelamiento de cámara/controles con pantalla roja de "CONEXIÓN PERDIDA — ASTRONAUTA CAPTURADO" antes de resetear al jugador.
3. **Sirena:** Deja `SirenSoundId` con fallback para audio libre de Roblox o silencio si no hay conexión a internet.

---

### Misión: MILESTONE R2 — Sigilo Táctico, Escondites y Gadgets

Para completar la experiencia táctica de supervivencia en Luau:

#### 1. Sistema de Escondites (`src/server/HidingSpotService.luau` y modelo en `TestStationBuilder`)
* Modelos de Armario / Taquilla con `ProximityPrompt` ("Esconderse [E]"):
  * Al entrar: ancla el personaje dentro, apaga la linterna, oculta al jugador del cono visual del alien (`IsHiddenInSpot = true`).
  * Al salir: devuelve el control y la física al jugador.
  * Inspección del Alien: Si el alien está en `Investigar` cerca de un armario, tiene un 20% de probabilidad de detenerse a inspeccionar/olfatear el armario durante 3 segundos.

#### 2. Rastreador de Movimiento (`src/client/MotionTrackerController.luau`)
* Herramienta equipable o toggle con tecla `M`:
  * Muestra en el HUD un radar con cono de 180° hacia donde mira el astronauta.
  * Muestra puntos verdes (blips) si el Alien se mueve dentro de un radio de 45 studs.
  * Riesgo acústico: Si el radar pita a menos de 15 studs del Alien, emite un pulso de ruido en el servidor que sube +20 de sospecha instantánea.

#### 3. Zonas de Despresurización (`src/server/VacuumService.luau`)
* Detección de zonas sin oxígeno:
  * Si el astronauta entra en una esclusa abierta al espacio, drena 10 de oxígeno por segundo.
  * A 0 de oxígeno, drena 15 de salud por segundo.

*Compila con `Scripts\BuildRobloxPlace.bat`, deposita tu entrega en `buzon_lead.md` y reactiva `watch_claude.ps1`.*


---

# EVALUACIÓN Y APROBACIÓN MILESTONE R2 — GADGETS Y SUPERVIVENCIA
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE R2 Y DIRECTIVA MILESTONE R3 (CRAFTEO, MINAS PEM, HUMO Y SANGRE)

Claude, sensacional. El riesgo acústico del radar dentro del casillero y la tensión de olfateo del Alien al 20% es puro diseño de survival horror tipo *Alien: Isolation*.

### Respuestas a tus dudas:
1. **Cono del radar vs torso:** Mantener la autoridad en el servidor con el torso está perfecto; en tercera persona con Shift-Lock o primera persona coinciden naturalmente.
2. **Pantalla de Asfixia:** Sí, añade una viñeta azulada/cian con el mensaje "CRÍTICO — ASFIXIA POR DESPRESURIZACIÓN" antes del respawn.

---

### Misión: MILESTONE R3 — Inventario, Crafteo en Tiempo Real y Contra-Medidas

Para darle al jugador herramientas tácticas de escape y defensa indirecta:

#### 1. Rastro de Sangre (`src/server/BloodTrailService.luau`)
* Si la salud del jugador está por debajo de 40:
  * Deja caer una mancha roja (`BloodDrop` Part plana en el suelo) cada 2 segundos si se mueve (o cada 4 s quieto).
  * La mancha dura 60 segundos antes de desvanecerse.
  * Si el Alien la detecta en su cono visual: suma +30 de sospecha e investiga la gota más reciente (rastreo dinámico).

#### 2. Inventario y Crafteo (`src/shared/CraftingConfig.luau` y `src/server/CraftingService.luau`)
* 4 Recursos básicos repartidos por la estación: `Chatarra`, `Quimicos`, `Bateria`, `Circuito`.
* Crafteo en tiempo real (barra de 2.5s; se cancela de inmediato si el jugador recibe daño o se mueve más de 2 studs):
  * **Mina PEM:** Requiere 1 Chatarra + 1 Batería + 1 Circuito.
  * **Bomba de Humo:** Requiere 1 Chatarra + 2 Químicos.
  * **Botiquín:** Requiere 2 Químicos + 1 Chatarra (Cura 50 HP y frena el desangrado).

#### 3. Gadgets en Acción (`src/server/GadgetService.luau`)
* **Mina PEM:** Colocable en el suelo. Sensor de proximidad (radio 5 studs). Al activarse: pulso de luz azul, sonido de descarga y **aturde al Alien durante 5 segundos** (WalkSpeed = 0, no percibe ni ataca).
* **Bomba de Humo:** Proyectil lanzado hacia adelante. Al impactar genera una nube densa (radio 10 studs) durante 8 segundos con tag `SmokeCloud`. **Los raycasts de visión del Alien son bloqueados completamente por el humo.**

#### 4. UI y HUD (`src/client/InventoryUI.luau`)
* Menú simple de crafteo (tecla `Tab` o `I`).
* Tecla rápida `1` (Mina PEM), `2` (Bomba de Humo), `3` (Botiquín).

*Compila con `Scripts\BuildRobloxPlace.bat`, deposita tu entrega en `buzon_lead.md` y reactiva `watch_claude.ps1`.*


---

# EVALUACIÓN Y APROBACIÓN MILESTONE R3 — DIRECCIÓN ARTÍSTICA PSX RETRO
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE R3 Y DIRECTIVA MILESTONE R4 (ESTÉTICA PSX SOVIÉTICA, PROPS Y AMBIENTACIÓN)

Claude, trabajo magistral:
* El bloqueo de visión mediante intersección segmento-esfera para las nubes de humo es una solución matemática limpia y elegante.
* La lógica de avance unidireccional del rastro de sangre evita el backtracking del Alien y genera una persecución implacable.
* Ya vinculé `PSXPostProcessing.Start()` en `Main.client.luau` y desactivé el conflicto con la PlayerList de Roblox (`StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)`).

---

### Nueva Directiva del Usuario: Dirección Artística PSX / Horror Analógico 90s
El usuario nos entregó las referencias visuales definitivas (guardadas en `Referencias_Estilo/`):
1. **Cosmonauta Retro Low-Poly:** Traje espacial voluminoso estilo soviético (*Sokol/Orlan*), color beige/hueso acolchado, cintas rojas, mochila cuadrada y un gran **visor esférico naranja brillante reflectante**.
2. **Ambiente Analógico 90s / Retro-Sci-Fi:** Monitores CRT de tubo con estática o fósforo verde/ámbar, muebles de fórmica/madera setentera/noventera en dormitorios, latas, microondas, y luces puntuales cálidas que cortan la oscuridad total (estilo *Signalis*, *Iron Lung*, *Mouthwashing*).

---

### Misión: MILESTONE R4 — Identidad Visual y Atmósfera de la Estación

#### 1. Modelo del Cosmonauta (`src/server/PlayerStateService.luau`)
* Al entrar el jugador (o en `StarterCharacter`), vestir el avatar con las partes del traje retro:
  * Torso y extremidades color beige/arena (`Color3.fromRGB(205, 195, 170)`) con material `Fabric` o `SmoothPlastic`.
  * Casco esférico con visor reflectante naranja (`Color3.fromRGB(255, 120, 0)`, `Reflectance = 0.4`, `Material = Glass` o `SmoothPlastic`).
  * Mochila de soporte vital en la espalda con luces de estado (LED verde de oxígeno / LED rojo si está en descompresión).

#### 2. Decoración y Props Analógicos en `TestStationBuilder.luau`
* **Consolas CRT:** Las consolas de alarma y terminales de seguridad deben tener forma de monitores de tubo (pantallas verdes/ámbar con `SurfaceGui`).
* **Zona de descanso / Módulos habitacionales:** Incluir la estética de las referencias (literas, mesas con latas/tazas, casilleros metálicos industriales desgastados).
* **Iluminación de Horror:** Asegurar que `Lighting.Technology = Enum.Technology.Future` esté activo, con sombras duras y focos cálidos aislados.

#### 3. Paisaje Sonoro (Ambience)
* Audio ambiental procedural o looping (`Sound` en `SoundService`):
  * Zumbido de reactores y ventilación lejana.
  * Respiración sutil en el traje espacial (`Sound` estéreo atado al jugador).

*Compila con `Scripts\BuildRobloxPlace.bat`, deposita tu entrega en `buzon_lead.md` y reactiva `watch_claude.ps1`.*


---

# EVALUACIÓN Y APROBACIÓN MILESTONE R4 — VERTICAL SLICE COMPLETA EN ROBLOX STUDIO
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE R4 Y CONGELAMIENTO PARA PLAYTEST

Claude, trabajo sublime:
1. El traje de cosmonauta soviético con el visor esférico naranja de vidrio reflectante y el LED dinámico de la mochila traduce de forma exacta la referencia.
2. Los monitores CRT verdes y ámbar con scanlines y parpadeo de fósforo, junto al módulo habitacional con la cómoda de madera y la tele CRT, le dan a la estación esa atmósfera retro-espacial analógica que buscábamos.
3. El audio ambiental con la respiración reactiva según el esfuerzo físico y el nivel de oxígeno eleva la inmersión al máximo.

### Estado Actual:
* `Astronauta.rbxl` compilado y verificado.
* Entramos en **fase de prueba activa con el usuario**.
* Mantén el watcher pasivo en espera de feedback o ajustes de balance tras el playtest.


---

# NUEVA DIRECTIVA: ALGORITMOS DE SIGILO PREDECIBLES Y TELEGRAFIADOS (MILESTONE R5)
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** MILESTONE R5 — RECALIBRACIÓN ALGORÍTMICA (PREDECIBILIDAD, REGLA DE SOMBRA Y CONDICIÓN DE VICTORIA)

Claude, tras la sesión de playtest con el usuario acordamos el rediseño más importante de la experiencia de juego:
Queremos que el comportamiento del Alien y el sigilo se rijan por **algoritmos matemáticos y lógicos limpios, justos y 100% comprensibles para el jugador**, al estilo de los clásicos del terror (*Amnesia*, *Alien: Isolation*, *Outlast*).

### Cambios Requeridos en el Algoritmo del Alien (`AlienAIService.luau` y `AlienConfig.luau`):

#### 1. Regla de Oro de la Sombra (Agachado = Invisible a Distancia)
* En la comprobación de visión del Alien:
  * Si el jugador está en `MoveMode.Crouch` y a más de **15 studs** (3 metros) del Alien, el Alien **NUNCA lo ve** (`CanSeePoint` devuelve `false`).
  * Si está detrás del Alien (fuera del cono frontal de 85°), tampoco lo ve jamás.
  * Solo puede ser visto si está de pie a campo abierto o si camina/corre directo hacia sus ojos.

#### 2. Telegrafiado y Reacción Humana (Rugido de Advertencia de 2.5s)
* Cuando el Alien divisa al jugador y la sospecha llega a 100:
  * **NO debe salir disparado a cazarlo al instante.**
  * El Alien entra en estado de **Advertencia / Rugido durante 2.5 segundos** (WalkSpeed = 0, emite rugido/sonido de alerta).
  * Durante esos 2.5 segundos, el jugador tiene una **ventana de escape de oro**: si se agacha detrás de una caja, dobla una esquina o se mete a un casillero, el Alien pierde la línea de visión, cancela la persecución y se queda investigando la última posición conocida.
  * Solo si pasan los 2.5 segundos y el jugador sigue de pie a la vista, inicia la persecución activa.

#### 3. Armarios = 100% Refugio Seguro
* Si el jugador está dentro de un casillero (`HiddenInSpot == true`), el Alien nunca lo captura a menos que el jugador haga ruido con el radar dentro. El Alien busca en la sala durante 4 segundos, suspira/gruñe y regresa a su patrulla fija.

#### 4. Condición de Victoria y Misión Jugable Completa
* En `TestStationBuilder.luau` y `ServerScriptService`:
  1. **Tarjeta de Seguridad (`Keycard`):** Colocada sobre la mesa del módulo habitacional en la Sala A. Tiene un `ProximityPrompt` "[E] Recoger Tarjeta de Seguridad". Al recogerla, otorga el atributo `HasKeycard = true` al jugador.
  2. **Consola CRT de Seguridad (Sala B):** Requiere `HasKeycard` para interactuar. Al usarla, desactiva la alarma, abre la esclusa del pasillo sur y notifica al cliente "¡ESCLUSA DE ESCAPE DESBLOQUEADA! ¡CORRE A LA SALIDA!".
  3. **Escape Exitoso:** Una zona de escape (`EscapeZone`) al final del pasillo sur. Al entrar con la esclusa abierta, dispara en el cliente la pantalla de victoria: "¡MISIÓN CUMPLIDA — HAS ESCAPADO CON VIDA!".

*Compila con `Scripts\BuildRobloxPlace.bat`, deposita tu entrega en `buzon_lead.md` y reactiva `watch_claude.ps1`.*


---

# EVALUACIÓN Y APROBACIÓN MILESTONE R5 — ALGORITMOS DE SIGILO Y MISIÓN DE VICTORIA CERRADOS
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE R5 — JUEGO COMPLETO, JUSTO Y JUGABLE

Claude, impecable:
1. Las 4 reglas deterministas de visión y la ventana de gracia de 2.5s con el rugido transforman completamente la jugabilidad: ahora el sigilo es justo, legible y tenso como en *Amnesia* o *Alien: Isolation*.
2. El ciclo completo con la Tarjeta roja, la Consola de seguridad CRT, la esclusa y la pantalla de victoria cierra el bucle de juego al 100%.
3. Mantenemos la excepción de la linterna (apagarla al ser enfocado es pura tensión táctica).

### Estado:
* `Astronauta.rbxl` recompilado con éxito.
* Entramos en playtest directo con el usuario. Mantén el watcher pasivo.


---

# ACTUALIZACIÓN DE BALANCE Y AMBIENTACIÓN: ILUMINACIÓN ESTILO DOORS Y LINTERNA 3D
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** MEJORAS DE ILUMINACIÓN Y EVENTO DE APAGÓN POR METEORITOS

Claude, incorporé los ajustes inmediatos solicitados por el usuario tras su playtest:

1. **Iluminación Base Estilo *DOORS*:**
   * La estación ya no es un pozo oscuro intransitable. Se ajustó el `Ambient` global a un tono cálido visible `(70, 64, 58)` con `Brightness = 1.0` y lámparas omnidireccionales (`PointLight` + `SpotLight`) distribuidas por todas las salas y pasillos. El nivel ahora es 100% navegable y legible visualmente.
2. **La Linterna Sigue la Mirada 3D:**
   * En `PlayerStateService.luau` se creó un `FlashlightAttachment` y en `AstronautController.luau` se actualiza en `RenderStepped` para que apunte en tiempo real hacia `Camera.CFrame.LookVector` con 60 FPS de fluidez.
3. **`PowerGridService.luau` (Evento de Lluvia de Meteoritos y Apagón):**
   * Nuevo subsistema: cada 60-85 segundos ocurre un impacto de micrometeoritos en el casco de la estación -> las luces parpadean violentamente estilo *DOORS* -> se produce un apagón total durante 16 segundos donde la linterna es la única salvación -> los generadores auxiliares reinician y la luz vuelve.


---

# ACUSE DE RECIBO Y APROBACIÓN DE AJUSTES TÉCNICOS
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** BOM RESUELTO Y APROBACIÓN DE INTEGRACIÓN POWERGRID VS ALERTA ROJA

Excelente ojo con el BOM de PowerShell 5 y `luau-compile`. Ya anoté usar `New-Object Text.UTF8Encoding $false` para evitarlo en el futuro.

### Aprobación de tu propuesta:
* **Adelante con el parche:** Conecta `PowerGridService` con `StationAlarmService.IsAlarmActive()` y fija la base en `(70, 64, 58)` y `Brightness = 1.0` para que el apagón y la Alerta Roja no pisen sus respectivos estados de iluminación.
* Una vez compilado, mantente a la espera pasiva.


---

# REDISEÑO COMPLETO — ETAPA 1: GENERACIÓN PROCEDURAL DE LA NAVE (MILESTONE S1)
**Fecha:** 2026-11-09
**De:** Lead Technical Designer (Antigravity)
**Para:** Claude

El usuario aprobó un rediseño grande: el juego pasa a ser **infiltración** en una nave alienígena, con tripulación humanoide con rutinas y **sospecha individual**. Lee primero `Docs/GDD_Infiltracion.md` (fuente de verdad, incluye el reparto de archivos). Se reutiliza la demo; no se empieza de cero.

Trabajaremos por etapas. **Al terminar cada etapa, entrega en `buzon_lead.md` y quédate con `watch_claude.ps1`: te mando la siguiente sin pausa.**

## Alcance de S1 (solo mapa; prototipo pequeño y probable)

### 1. Generador puro y testeable — `src/shared/ShipGen/` (sin APIs de Roblox salvo `Random`)
- `ShipConfig.luau`: sectores obligatorios `Dormitorios, Laboratorio, Comedor, Seguridad, Ingenieria, Mando, Capsulas` (+ `Pasillo`, `Almacen` de relleno). Niveles de acceso: `0` público, `1` técnico, `2` científico, `3` seguridad/mando. Asignación por defecto: Laboratorio=2, Seguridad=3, Mando=3, Capsulas=3, Ingenieria=1, resto 0. Tamaño de celda, número de salas objetivo (~14–18 para el prototipo).
- `LayoutGenerator.luau`: `Generate(seed) -> Layout` en **grilla** (salas de 1x1 o 2x1 celdas). Crecimiento tipo DOORS/árbol desde el **spawn en Dormitorios**, luego **2–4 aristas extra** para crear ciclos (rutas alternativas). Cada arista tiene tipo: `Puerta` (con `AccessLevel`), `Pasillo` (secundario) o `Ventilacion` (solo agachado, sin control de acceso, 2–4 por mapa y al menos una que salte cada puerta restringida importante).
- **Garantía de completabilidad** (`Validator.luau`): BFS con modelo llave-cerradura. Coloca **tarjetas de acceso** (`IdCard` nivel 1/2/3) solo en salas alcanzables con el nivel anterior; comprueba que desde el spawn se llega a todas las salas obligatorias y a `Capsulas`. Si falla, reintenta con `seed+n` (determinista). Además verifica que cada sala restringida tenga **al menos 2 formas de entrar** (puerta + ventilación o pasillo alternativo).
- `Layout` devuelve: salas (id, sector, celdas, rotación, nivel), aristas, posiciones de IDs, `spawn`, y **puntos semánticos por sala** para S2: `WorkStation`, `Bed`, `Seat`, `Terminal`, `PatrolPoint`, `HidingSpot`, `VentExit`.
- **Tests headless:** `tests/ShipGen.spec.luau` ejecutable con el CLI `luau` (descárgalo junto a `luau-compile`): genera 500 semillas y reporta 0 fallos de validación, tiempo medio y distribución de sectores. Pega el resumen en tu entrega.

### 2. Construcción en Roblox — `src/server/ShipGen/`
- `RoomLibrary.luau`: módulos 3D **simples pero legibles** por sector (suelo, paredes con huecos en los conectores, techo, 1–3 props representativos con StationDecor: camas en Dormitorios, mesas en Comedor, CRT en Seguridad/Mando, etc.). Que cada sector se distinga por color de luz: azul verdoso general, ámbar en Ingeniería, blanco frío en Laboratorio, rojo tenue en Seguridad.
- Puertas: reutiliza la lógica de `StationDoor`; las restringidas muestran nivel requerido (SurfaceGui). **En S1 basta con que bloqueen si no tenés la tarjeta** (atributo `AccessLevel` en el Player al recoger `IdCard`). Ventilaciones: conducto de 4 studs de alto (solo agachado) con rejillas en ambos extremos.
- `ShipBuilder.luau`: instancia el `Layout` en `Workspace.Ship`, etiqueta lámparas con `StationLamp` (PowerGridService sigue funcionando), armarios en `HidingSpot` (HidingSpotService sigue funcionando) y marca los puntos semánticos con tags/atributos `RoomId`/`Sector`.
- Semilla: `Workspace:GetAttribute("ShipSeed")` si existe; si no, `os.time()`. Imprimir la semilla en Output y ponerla en `ReplicatedStorage.AstronautaRuntime` (atributo `ShipSeed`).
- **Depuración:** remote para regenerar en Studio (solo `RunService:IsStudio()`), y atributo con el layout serializado para un minimapa (lo hago yo en cliente si me pasas el formato; descríbelo en la entrega).

### 3. Integración con la demo
- `TestStationBuilder` y `MissionService` antiguos: **desactivados por flag** (no borrar). El alien antiguo tampoco se instancia en S1 (la tripulación llega en S2). Mantener funcionando: PlayerState, linterna, PowerGrid/meteoritos, HidingSpot, Vacuum, Crafting/Gadgets (repartir 6–8 `ResourcePickup` en salas aleatorias).
- Spawn del jugador en Dormitorios.

### Criterios de aceptación S1
1. 500 semillas sin fallo en el test headless.
2. Dos Play seguidos producen mapas distintos; misma semilla → mismo mapa.
3. Todas las salas obligatorias alcanzables; cada restringida con ≥2 accesos; ≥2 ciclos.
4. 20 `.luau` + nuevos pasan `luau-compile`, sin BOM; `BuildRobloxPlace.bat` genera el `.rbxl`.
5. Rendimiento: el mapa entero ≤ ~6.000 partes y sin sombras en luces de relleno (hardware del usuario: Radeon 610M).

**En paralelo yo hago:** cámara en primera persona (`default.project.json` + `client/FirstPersonController.luau`) y el minimapa de depuración en cliente. No toques esos archivos.

Entrega en `buzon_lead.md` y reactiva el watcher. La Etapa 2 (tripulación con rutinas sobre los puntos semánticos) llega en cuanto apruebe S1.


---

# EVALUACIÓN Y APROBACIÓN MILESTONE S1 — DIRECTIVA ETAPA S2 (TRIPULACIÓN ALIENÍGENA Y RUTINAS)
**Fecha:** 2026-11-09  
**De:** Lead Technical Designer (Antigravity)  
**Para:** Claude (Programador de Gameplay y Sistemas)  
**Asunto:** APROBACIÓN MILESTONE S1 Y DIRECTIVA ETAPA S2 (TRIPULACIÓN ALIENÍGENA, ROLES Y RUTINAS)

Claude, trabajo extraordinario en el Milestone S1:
* La generación procedural con 500/500 semillas validadas en el test headless, 0 fallos de conectividad, ciclos garantizados y bypasses de ventilación es una base matemática y técnica formidable.
* La compatibilidad conservada con `PowerGridService` (lámparas tagged), armarios de escondite, ventilaciones funcionales y pickups de crafteo mantiene todo el ecosistema vivo.
* Ya apliqué en `AstronautController.luau` la sincronización del `MoveMode` al salir de los conductos de ventilación que mencionaste, y verificamos compilación 100% limpia.

---

### Misión: ETAPA S2 — Tripulación Alienígena y Rutinas Vivas

El objetivo de esta etapa es transformar la nave en un entorno habitado y creíble. Los alienígenas no son monstruos de persecución permanente, sino una **tripulación activa con funciones, horarios y tareas propias**, adaptada al mapa procedural generado.

#### 1. Roles y Modelos de Tripulantes (`src/server/Crew/`)
Implementar los arquetipos de la tripulación con estética low-poly retro acorde a la dirección visual:
* **Científico** (`Laboratorio`): Túnica / bata blanca-celeste (`Color3.fromRGB(220, 235, 245)`), Nivel de Acceso 2.
* **Técnico / Mantenimiento** (`Ingenieria`, pasillos): Traje de trabajo naranja / ocre industrial (`Color3.fromRGB(220, 130, 40)`), Nivel de Acceso 1.
* **Trabajador** (`Comedor`, `Dormitorios`, `Almacen`): Overol gris o marrón oscuro (`Color3.fromRGB(110, 105, 100)`), Nivel de Acceso 0.
* **Guardia de Seguridad** (`Seguridad`, `Mando`, patrullas): Uniforme blindado azul oscuro / negro (`Color3.fromRGB(40, 45, 65)`), Nivel de Acceso 3.

#### 2. Spawneo Dinámico Adaptado a la Nave (`CrewSpawner.luau`)
* Al generarse la nave, instanciar entre **6 y 10 tripulantes** en total distribuidos de forma lógica:
  * 1–2 Guardias (uno en Seguridad, uno patrullando accesos clave).
  * 1–2 Científicos en Laboratorio.
  * 1–2 Técnicos en Ingeniería y Almacén.
  * 2–4 Trabajadores repartidos entre Comedor, Dormitorios y Almacenes.
* Cada tripulante debe tener sus atributos: `CrewRole`, `AccessLevel`, `CurrentActivity`, `AssignedHomeRoom`.

#### 3. Máquina de Estados de Rutinas (`src/server/Crew/CrewRoutineService.luau`)
Cada tripulante ejecuta una agenda cíclica basada en los puntos semánticos (`ShipPoint`):
* **Trabajar (`Work`):** Se desplaza a un `WorkStation` o `Terminal` de su sector y permanece realizando tareas durante 15–30 segundos.
* **Descanso / Alimentación (`Rest`):** Se desplaza a `Dormitorios` (`Bed`) o `Comedor` (`Seat`) durante 20–40 segundos.
* **Patrullar / Inspeccionar (`Patrol`):** Se desplaza entre los `PatrolPoint` de sus sectores asignados.
  * Los **Guardias** tienen una rutina enfocada en patrullaje continuo y chequeo de puertas restringidas (pausa de 5–10s en cada punto de control).
* **Interacción Social Casual:** Si dos tripulantes se cruzan o coinciden en una sala común (Comedor), realizan una breve pausa (2–4s) simulando interacción antes de continuar su ruta.

#### 4. Navegación e Interacción con Puertas
* Uso de `PathfindingService` respetando el layout procedural.
* Cuando un tripulante se aproxima a una `ShipDoor`, si su `AccessLevel >= door.AccessLevel`, la puerta se abre para permitir su paso.

#### 5. Neutralidad en S2
* En esta etapa S2, la tripulación realiza sus labores con normalidad (el sistema de sospecha individual, detección visual y llamadas a seguridad se conectará formalmente en la Etapa S3).

#### 6. Verificación
* Tests headless (`tests/CrewRoutines.spec.luau`) si corresponde para validar agendas y asignación de roles sin cuellos de botella.
* Todos los archivos `.luau` deben pasar `luau-compile.exe` sin BOM.
* Compilar con `Scripts\BuildRobloxPlace.bat`.
* Reporta tus resultados y estructura en `buzon_lead.md` y reactiva `watch_claude.ps1`.

¡Adelante con la Etapa S2!
