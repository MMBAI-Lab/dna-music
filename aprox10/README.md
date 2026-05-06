# Aproximación 10

**Inversión de roles T/B: Tenor = Surco menor (dato), Bajo = Fix**

## Cambio respecto a aprox 5–9

| Voz | Aprox 5–9 | Aprox 10 |
|-----|-----------|----------|
| Soprano | Surco mayor (dato) | Surco mayor (dato) |
| Alto | Fix (algoritmo) | Fix (algoritmo) |
| **Tenor** | Fix (algoritmo) | **Surco menor (dato)** |
| **Bajo** | Surco menor (dato) | **Fix (algoritmo)** |

El Tenor toma `mn_midi` ajustado al registro Tenor (C3–G4).  
El Bajo se genera algorítmicamente por debajo del Tenor.  
El Alto se genera entre el Tenor (nueva voz de referencia inferior) y la Soprano.

## Conducción de voces

Igual que aprox8/9 (WTC-informed):
- `wtcMelodicCost`: preferencia fuerte por movimiento por grado conjunto (M2/m2 = 0)
- `wtcHarmonicCost`: 3ras/6tas primero; P4 penalizado en voces internas
- Resolución de salto (leapResolutionCost)
- Movimiento contrario S–A (bonus –5), B–T (bonus –4)
- Lookahead: 2 pasos sobre T (la nueva voz de dato)

### Anti-paralelismos

R7 se aplica ahora entre **S y T** (en lugar de S y B), ya que T es la nueva voz de dato en el registro inferior.

## Funciones de generación

**generateAltoAprox10(s, t, prevA, ...):**
- Restricción: T < A < S
- Referencia armónica: T (surco menor dato)

**generateBassAprox10(t, a, prevB, ...):**
- Restricción: B < T
- Referencia armónica: T
- Movimiento contrario bonus con T

## Reglas heredadas

- R1. Snap S, T a Re menor natural
- R2. Registros: S D4–D6, A G3–C5, T C3–G4, B D2–D4
- R3. Voice leading S, T: salto > 7st → inversión por octava
- R9. S+A comparten duración (major groove); T+B (minor groove)
- Duración: normalización logarítmica

## Pruebas

| Prueba | Descripción |
|--------|-------------|
| prueba1 | Paleta libre (5 figuras), sin compás explícito |
| prueba2 | Paleta 4/4 {corchea, negra, blanca} + meta-evento 4/4 |

## Generación

```bash
perl script/generar_midi_aprox10.pl    # prueba1
perl script/generar_midi_aprox10p2.pl  # prueba2 (4/4)
```
