# Aproximación 7 — Correcciones con anticipación (lookahead)

Rediseño del algoritmo de generación de voces de corrección (Alto y Tenor) con el objetivo de hacer el sistema **universalmente aplicable a cualquier secuencia de ADN** sin intervención manual.

## Motivación: hacia una aplicación web

En todas las aproximaciones anteriores (5 y 6), las correcciones armónicas se generaban de forma greedy nota por nota, sin considerar qué nota venía después. Esto producía transiciones subóptimas y ocasionalmente semitonos cromáticos que suenan ajenos a Re menor natural.

La clave para un sistema universal: dado el tetranucleótido XXXX en posición i, el siguiente tetranucleótido siempre comparte 3 bases (solapamiento). Por ejemplo, desde AAAT los únicos posibles siguientes son AATA, AATC, AATG o AATT. En una secuencia real (o pegada por un usuario en una web) **el siguiente tetranucleótido siempre es conocido de antemano**. Esto permite que el algoritmo anticipe la próxima armonía al elegir la nota actual.

## Mejoras sobre aprox6

| Regla | aprox6 | aprox7 |
|---|---|---|
| Anticipación | No | **Lookahead +1**: minimiza disonancia en i y en i+1 |
| Semitonos cromáticos | No penalizado | **Penalización 12** (vs movimiento normal 1-6) |
| Tritono (Bb↔E) | No penalizado | **Penalización 5** |
| Movimiento contrario | No | **Penalización 3** por movimiento paralelo a soprano |
| Paralelismos | S–A post-hoc (R8) | **S–A y B–T dentro de la función de coste** |
| Atracción al centro | No | Penalización suave (1 pt cada 4st del centro) |

## Función de coste (Alto y Tenor)

```
score(c) =
  min(|c - prev|, 6)  ×  1    suavidad (cap: saltos > 6st no se penalizan extra)
  (|c - prev| == 1)   × 12    evitar semitono cromático
  (|c - prev| == 6)   ×  5    evitar tritono (Bb↔E en Re menor)
  ¬consonante(c, b)   × 15    disonancia con bajo [i] — actual
  ¬consonante(c, b+1) ×  8    disonancia con bajo [i+1] — anticipada (lookahead)
  (s - c < 3st)       ×  5    espacio mínimo entre Alto y Soprano
  paralel.perf.(S,A)  × 20    5as/8as paralelas S–A
  paralel.perf.(B,T)  × 20    5as/8as paralelas B–T  (solo Tenor)
  dir.paralela(S)     ×  3    preferir movimiento contrario a Soprano
  (c == prev)         ×  3    variedad melódica (penalizar nota repetida)
  |c - centro|/4      ×  1    atracción suave al centro del registro
```

La R8 post-hoc (corrección de paralelismos S–A) queda absorbida. La R7 (corrección S–B) se mantiene.

## Resultados sobre la secuencia de prueba (231 tetranucleótidos)

| Métrica | aprox6/prueba1 | aprox7/prueba1 |
|---|---|---|
| Disonancias S–B | 91 | 91 (heredadas de R7, sin cambio) |
| Disonancias A–B | — | **0 / 231** (100% consonante) |
| Disonancias T–B | — | 40 / 231 (17%) |
| Semitonos en Alto | — | **0** |
| Semitonos en Tenor | — | 7 |

El Alto resulta 100% consonante con el Bajo. Los 40 casos de disonancia en Tenor corresponden a posiciones donde la restricción B < T < A fuerza la nota hacia intervalos de 2ª o 7ª (no hay posición consonante disponible entre B y A).

---

## prueba1 — Lookahead, Re menor, 72 BPM, Grand Piano + Contrabajo

| Voz | Fuente | Registro | Instrumento | Canal |
|---|---|---|---|---|
| Soprano | Major groove (datos) | D4–D6 | Acoustic Grand Piano | 0 |
| Alto | Generada (corrección) | G3–C5 | Acoustic Grand Piano | 1 |
| Tenor | Generado (corrección) | C3–G4 | Acoustic Grand Piano | 2 |
| Bajo | Minor groove (datos) | D2–D4 | Contrabass | 3 |

Misma normalización logarítmica de duraciones que aprox6 (R9: S+A comparten major groove, T+B comparten minor groove).
