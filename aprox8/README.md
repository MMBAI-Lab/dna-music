# Aproximación 8

**Conducción de voces inspirada en el Clave Bien Temperado (Bach)**

## Contexto

Se analizaron los 24 archivos MusicXML del Clave Bien Temperado Libro I (BWV 846–869).
Los hallazgos del corpus que informan esta aproximación:

- El **70 % de los intervalos melódicos en las fugas son M2 o m2** (grado conjunto).
  Las voces internas de Bach se mueven casi siempre por paso; los saltos son la excepción.
- Los **intervalos armónicos simultáneos más frecuentes son 3ras (m3/M3) y 6tas (m6/M6)**.
  Las cuartas (P4) se evitan entre voces internas; las quintas (P5) son toleradas.
- **Resolución de salto**: un salto de P4 o mayor va seguido casi siempre de un movimiento
  en dirección contraria (paso — leap resolution).
- El **movimiento contrario** entre voces externas (S vs B) y entre voces internas
  adyacentes es una característica constante de la escritura bachiana.

## Diferencias respecto a aprox7

| Aspecto | Aprox 7 | Aprox 8 |
|---|---|---|
| Coste melódico | Penaliza semitonos y tritonos | `wtcMelodicCost`: M2/m2 = 0; P4 = 9; P5+ = 15/24 |
| Coste armónico | Consonancias clásicas (P1,m3,M3,P5,m6,M6) | `wtcHarmonicCost`: m3/M3 = 0; m6/M6 = 1; P4 = 7; P5 = 4; tritono = 20 |
| Resolución de salto | — | Dos saltos ≥ m3 consecutivos en misma dirección: +10 |
| Movimiento contrario S–A | Penaliza paralelo (+3) | Bonus activo –5 si van en direcciones opuestas |
| Movimiento contrario T–B | Penaliza paralelo (+3) | Bonus activo –4 si van en direcciones opuestas |
| Lookahead | 1 paso (bNext) | **2 pasos** (bNext + bNext2) |

## Función de coste completa

**Alto:**
```
wtcMelodicCost(Δ)     × 1
wtcHarmonicCost(c,b)  × 2
wtcHarmonicCost(c,b+1)× 1      ← lookahead +1
wtcHarmonicCost(c,b+2)× 0.5    ← lookahead +2
leapResolutionCost    × 10
movimiento contrario S–A        → bonus –5
paralel. 5as/8as S–A  × 20
espacio mínimo S–A < 3st × 4
atracción al centro   × 0.1
```

**Tenor** (igual + pesos distintos sobre armónico):
```
wtcHarmonicCost(c,b)  × 1.5
wtcHarmonicCost(c,a)  × 0.8
movimiento contrario T–B        → bonus –4
paralel. 5as/8as S–T + B–T × 20 c/u
```

## Reglas heredadas (sin cambio)

- R1. Snap S, B a Re menor natural {D, E, F, G, A, Bb, C}
- R2. Registros: S D4–D6, A G3–C5, T C3–G4, B D2–D4
- R3. Voice leading S, B: salto > 7st → inversión por octava
- R7. Paralelismos S–B: 5as/8as → mover soprano un grado arriba
- R9. S+A comparten duración (major groove); T+B (minor groove)
- Duración: normalización logarítmica (misma que aprox6/7)

## Parámetros

| Parámetro | Valor |
|---|---|
| Tempo | 72 BPM |
| PPQ | 480 ticks/beat |
| Instrumentos | S+A+T: Grand Piano (GM 0) · B: Contrabass (GM 43) |
| Secuencia | MiniABC (234 bases → 231 tetranucleótidos solapados) |

## Generación

```bash
perl script/generar_midi_aprox8.pl
```

Requiere los datos en `source/MUSIC.majorgroove/`, `source/MUSIC.minorgroove/`
y los CSV `data/notas_256_majorgroove_aprox1_2.csv`, `data/notas_256_minorgroove_aprox1_2.csv`.

---

## prueba1

- **Surcos:** major groove (Soprano+Alto) + minor groove (Tenor+Bajo)
- **Voces:** 4 (SATB), formato MIDI 1, 5 pistas (tempo + SATB)
- **Algoritmo:** Bach/CBI-informed — `wtcMelodicCost` + `wtcHarmonicCost` + lookahead×2
