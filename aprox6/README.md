# Aproximación 6 — Normalización logarítmica de duración

Idéntica a aprox5/prueba2 (4 voces SATB, Re menor, 72 BPM) salvo por el método de asignación de figuras rítmicas: se sustituye la normalización lineal del tiempo de vida media (aprox4/5) por una **normalización logarítmica**.

**Motivación:** con normalización lineal, los valores de tiempo de vida media se concentran en el extremo bajo del rango real (3.5–7 ps), lo que genera mayoría de corcheas y corcheas con punto. La escala logarítmica redistribuye mejor la densidad hacia negras y valores más largos.

**Fórmula:**
```
idx = floor( (log(ps) − log(ps_min)) / (log(ps_max) − log(ps_min)) × N )
```
donde N = 5 figuras. Los rangos de cada surco:
- Major groove: ps_min = 3.2712 ps, ps_max = 10.3063 ps
- Minor groove: ps_min = 3.3551 ps, ps_max = 11.8082 ps

**Comparación de distribuciones (256 tetranucleótidos):**

| Figura | Major lineal | Major log | Minor lineal | Minor log |
|---|---|---|---|---|
| Corchea | 20 | 17 | 13 | 8 |
| Corchea con punto | 61 | 71 | 86 | 90 |
| Negra | 42 | 93 | 30 | 115 |
| Negra con punto | 10 | 55 | 9 | 33 |
| Blanca | 7 | 20 | 2 | 10 |

**CSVs de referencia (en `data/`):**
- `notas_256_majorgroove_aprox3_6.csv` — extiende aprox3_4 con columna `aprox6_figura`
- `notas_256_minorgroove_aprox3_6.csv` — ídem para minor groove

---

## prueba1 — SATB Re menor, 72 BPM, normalización logarítmica

Basada directamente en aprox5/prueba2. Mismas reglas R1–R9, mismo tempo, misma estructura de voces. Única diferencia: `ps_to_ticks_log` en lugar de `ps_to_ticks_linear`.

**Estructura de voces:**
| Voz | Fuente | Registro | Canal |
|---|---|---|---|
| Soprano | Major groove (datos) | D4–D6 | 0 |
| Alto | Generada (corrección) | G3–C5 | 1 |
| Tenor | Generado (corrección) | C3–G4 | 2 |
| Bajo | Minor groove (datos) | D2–D4 | 3 |

**Distribución de figuras — 231 notas de la secuencia:**

| Figura | Soprano+Alto (major) | Tenor+Bajo (minor) |
|---|---|---|
| Corchea | 10 | 5 |
| Corchea con punto | 38 | 49 |
| Negra | 51 | 61 |
| Negra con punto | 29 | 18 |
| Blanca | 12 | 7 |

**Reglas aplicadas (heredadas de aprox5/prueba2):**
- **R1**: Snap a Re menor natural (D, E, F, G, A, Bb, C)
- **R2**: Forzar registro por voz (soprano D4–D6, alto G3–C5, tenor C3–G4, bajo D2–D4)
- **R3**: Voice leading: salto > 7 semitonos → inversión de octava
- **R4**: Alto y tenor usan exclusivamente grados de Re menor
- **R5**: Alto minimiza `movimiento + 15×disonante_con_bajo + 5×(< 3st de soprano)`
- **R6**: Tenor minimiza `movimiento + 15×disonante_con_bajo`; queda entre bajo y alto
- **R7**: Paralelismos 5as/8as S–B → mover soprano un grado arriba
- **R8**: Paralelismos 5as/8as S–A → mover alto un grado abajo
- **R9**: S+A comparten duración (major groove); T+B comparten duración (minor groove)

Disonancias S–B: 88 originales → 91 tras correcciones (igual que aprox5/prueba2).
