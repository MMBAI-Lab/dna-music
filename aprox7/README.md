# Aproximación 7 — Correcciones con anticipación (lookahead)

Rediseño completo del algoritmo de generación de voces de corrección (Alto y Tenor) con el objetivo de hacer el sistema **universalmente aplicable a cualquier secuencia de ADN** sin intervención manual. Esta aproximación es la base del motor de la aplicación web (`docs/`).

---

## Motivación: hacia una aplicación web

En las aproximaciones 5 y 6, las correcciones armónicas se generaban de forma greedy nota por nota, sin considerar qué nota vendría después. Esto producía:
- Transiciones subóptimas entre acordes consecutivos
- Semitonos cromáticos ocasionales que suenan ajenos a Re menor natural
- Correcciones post-hoc (R8) que podían entrar en conflicto con la lógica greedy

**La clave para un sistema universal:** dado el tetranucleótido XXXX en posición i, el siguiente comparte siempre 3 bases (solapamiento paso 1). Por ejemplo, desde AAAT los únicos sucesores posibles son AATA, AATC, AATG o AATT. En una secuencia real —o pegada por un usuario en una web— **el siguiente tetranucleótido siempre es conocido de antemano**. Esto permite anticipar la próxima armonía al elegir la nota actual.

Ejemplo concreto:
- Posición i = AAAT, posición i+1 = AATA → el algoritmo elige el Alto en AAAT para ser consonante tanto con el Bajo de AAAT como con el Bajo de AATA.
- Si la secuencia hubiera continuado con AATG (diferente a AATA), el Bajo en i+1 sería distinto → el Alto elegido en AAAT podría ser diferente.

---

## Reglas completas de aprox7

### Reglas heredadas sin cambio (R1–R4, R7, R9)

**R1 — Snap a la escala seleccionada**
Cada nota de Soprano y Bajo (derivadas de los datos de ADN) se cuantiza al grado más cercano de la escala elegida (por defecto Re menor natural: D E F G A Bb C). Se minimiza la distancia en semitonos; en caso de empate se sube al grado superior.

**R2 — Forzar al registro de la voz**
Cada nota se traslada a la octava dentro del registro asignado cuyo centro es más cercano:
- Soprano: D4–D6 (MIDI 62–86), centro A4 (MIDI 69)
- Alto: G3–C5 (MIDI 55–72), centro D4 (MIDI 62)
- Tenor: C3–G4 (MIDI 48–67), centro A3 (MIDI 57)
- Bajo: D2–D4 (MIDI 38–62), centro D3 (MIDI 50)

**R3 — Voice leading para Soprano y Bajo**
Si el intervalo entre una nota y la anterior supera 7 semitonos, se invierte por octava (ascendente → descendente o viceversa), siempre que el resultado quede dentro del registro. Esto suaviza los saltos melódicos grandes sin cambiar la nota elegida.

**R4 — Alto y Tenor usan exclusivamente grados de la escala**
Las voces de corrección solo pueden tomar notas pertenecientes a la escala activa, dentro de sus respectivos registros.

**R7 — Anti-paralelismos Soprano–Bajo**
Después de calcular todas las notas de Soprano y Bajo (post R1–R3), se recorre la secuencia: si dos acordes consecutivos forman quintas paralelas (intervalo mod 12 = 7 en ambos pasos) u octavas paralelas (intervalo mod 12 = 0), la Soprano se mueve un grado arriba en la escala. Esta corrección se aplica antes de generar Alto y Tenor.

**R9 — Duraciones independientes por dúo**
- Soprano + Alto comparten la duración del major groove (tiempo de vida media normalizado logarítmicamente)
- Tenor + Bajo comparten la duración del minor groove

Esto crea dos dúos rítmicamente independientes que se superponen.

---

### Función de coste para Alto y Tenor (NUEVO en aprox7)

Alto y Tenor se generan nota a nota maximizando la calidad armónica. Para cada candidato `c` en el registro de la voz (solo grados de la escala), se calcula un puntaje de penalización — se elige el candidato con menor puntaje.

```
score(c) =

  ── MOVIMIENTO ──────────────────────────────────────────────────────────
  min(|c − prev|, 6)   × 1     Suavidad: coste por semitono de movimiento,
                                con cap en 6 para no sobre-penalizar saltos
                                que pueden ser armónicamente correctos.

  (|c − prev| == 1)    × 12    Semitono cromático: los semitonos entre grados
                                adyacentes de la escala (Ej: E→F, A→Bb en Re
                                menor) suenan como cromatismo en voces de
                                corrección. Penalización fuerte.

  (|c − prev| == 6)    × 5     Tritono: el único tritono dentro de Re menor
                                natural es Bb↔E. Se penaliza el salto de 6
                                semitonos en las voces de corrección.

  ── ARMONÍA ─────────────────────────────────────────────────────────────
  ¬consonante(c, b[i])  × 15   Disonancia con el Bajo en la posición actual.
                                Consonancias aceptadas (intervalo mod 12):
                                P1=0, m3=3, M3=4, P5=7, m6=8, M6=9.

  ¬consonante(c, b[i+1])× 8   LOOKAHEAD: disonancia con el Bajo en la
                                posición siguiente. Peso menor que la actual
                                (8 < 15) porque el futuro es menos crítico
                                que el presente, pero suficiente para evitar
                                transiciones bruscas. En el último paso esta
                                penalización no se aplica (b[i+1] no existe).

  ── DISTRIBUCIÓN DE VOCES ───────────────────────────────────────────────
  (s − c < 3)          × 5     Proximidad a Soprano: si el Alto está a menos
                                de 3 semitonos de la Soprano el espacio entre
                                voces colapsa. Solo para Alto.

  ── PARALELISMOS ────────────────────────────────────────────────────────
  paralelas(S,A)[i]    × 20    5as/8as paralelas Soprano–Alto: si el intervalo
                                S−A en el paso anterior y en el actual son
                                ambos P5 (7st) o P8 (0st mod 12), se penaliza.

  paralelas(B,T)[i]    × 20    5as/8as paralelas Bajo–Tenor: misma lógica
                                para el par B–T. Solo se aplica al Tenor.

  ── MOVIMIENTO CONTRARIO ────────────────────────────────────────────────
  dir_paralela(S)      × 3     Si Soprano sube y la voz de corrección también
                                sube (o ambas bajan), se penaliza ligeramente.
                                Preferir movimiento contrario crea mayor
                                independencia de voces y reduce paralelismos
                                accidentales.

  ── VARIEDAD ────────────────────────────────────────────────────────────
  (c == prev)          × 3     Nota repetida: pequeña penalización para
                                favorecer variedad melódica en las correcciones.

  |c − centro| / 4     × 1     Atracción al centro del registro: penalización
                                suave (1 pt por cada 4 semitonos del centro)
                                evita que las voces deriven hacia los extremos
                                del registro por acumulación de pasos pequeños.
```

**Restricciones duras** (candidatos excluidos antes del scoring):
- Alto: `c < s` — el Alto siempre está estrictamente por debajo de la Soprano
- Tenor: `b < c < a` — el Tenor siempre está entre el Bajo y el Alto

**Fallback para Tenor:** si no hay ninguna posición válida entre Bajo y Alto (cruce de voces inevitable), se toma la nota de la escala más cercana a la mediana del espacio disponible.

---

## Comparación con aprox6

| Regla | aprox5/6 | aprox7 |
|---|---|---|
| Anticipación | Sin lookahead | **Lookahead +1**: b[i+1] en el scoring |
| Semitonos cromáticos | Sin penalización | **×12** (fuerte) |
| Tritono | Sin penalización | **×5** |
| Movimiento contrario | No | **×3** penalización por dirección paralela a S |
| Paralelismos S–A | Corrección post-hoc (R8) | **Integrado en scoring ×20** |
| Paralelismos B–T | No | **×20 en scoring del Tenor** |
| Atracción al centro | No | **×1 suave** |
| R8 post-hoc | Sí | **Eliminada** (absorbida en scoring) |
| R7 (S–B) | Sí | **Mantenida** sin cambio |

---

## Resultados sobre la secuencia de prueba (231 tetranucleótidos)

| Métrica | aprox6/prueba1 | aprox7/prueba1 |
|---|---|---|
| Disonancias S–B | 91 | 91 (heredadas de R7, sin cambio) |
| Disonancias A–B | sin medir | **0 / 231** — 100% consonante |
| Disonancias T–B | sin medir | 40 / 231 (17%) |
| Semitonos cromáticos en Alto | sin medir | **0** |
| Semitonos cromáticos en Tenor | sin medir | 7 / 230 (3%) |

El Alto es 100% consonante con el Bajo en toda la secuencia. Los 40 casos de disonancia en Tenor corresponden a posiciones donde la restricción `B < T < A` no deja espacio para ningún intervalo consonante (el espacio entre Bajo y Alto es demasiado estrecho o no contiene grados de la escala consonantes con el Bajo).

---

## prueba1 — Lookahead, Re menor, 72 BPM, Grand Piano + Contrabajo

| Voz | Fuente | Registro | Instrumento GM | Canal MIDI |
|---|---|---|---|---|
| Soprano | Major groove (datos ADN) | D4–D6 | Acoustic Grand Piano (0) | 0 |
| Alto | Generada (corrección) | G3–C5 | Acoustic Grand Piano (0) | 1 |
| Tenor | Generado (corrección) | C3–G4 | Acoustic Grand Piano (0) | 2 |
| Bajo | Minor groove (datos ADN) | D2–D4 | Contrabass (43) | 3 |

Normalización logarítmica de duraciones (igual que aprox6). R9: S+A comparten duración del major groove; T+B comparten duración del minor groove.
