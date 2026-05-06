# Aproximación 9

**Normalización rítmica del CBI + Conducción de voces Bach (Aprox 8)**

## Contexto

Se analizaron los 43 233 eventos de nota de los 24 archivos MusicXML del Clave Bien
Temperado Libro I (BWV 846–869) para obtener estadísticas de transición rítmica.

### Hallazgos del corpus (43 232 transiciones):

| Patrón | Frecuencia |
|--------|-----------|
| 1:1 — misma figura | **72.5 %** |
| 2:1 — la siguiente dura la mitad | 10.3 % |
| 1:2 — la siguiente dura el doble | 9.6 % |
| Otros (dotted, etc.) | 7.5 % |
| 1:3 o 3:1 (salto extremo) | **0 %** |

**Runs (secuencias de figura idéntica):** promedio 3.64 notas, picos en 4, 6, 8, 12, 16.

**Puntillos:** 2.85 % del corpus, siempre entre figuras adyacentes
(negra·→corchea, corchea·→semicorchea).

## Diferencias respecto a aprox8

Aprox 9 hereda íntegramente la conducción de voces de aprox 8
(coste WTC melódico, armónico, resolución de salto, movimiento contrario, lookahead×2)
y añade un post-procesado rítmico sobre las duraciones S+A y T+B:

### Algoritmo `applyWTCRhythm`

1. **Snap a figura** — ajuste logarítmico a la paleta {corchea, corchea·, negra, negra·, blanca}.
2. **Homogeneización de runs** — para cada par de notas consecutivas cuyos índices de figura
   difieren en exactamente 1 (ratio ≤ 1.5), ambas se elevan a la figura mayor.
   Esto aumenta la tasa de transiciones 1:1 hacia el 72.5 % del CBI.
3. **Tope de transición** — tras la homogeneización, cualquier transición > 2:1 o < 1:2
   se recorta a la figura válida más cercana dentro de ese límite.
   Esto elimina los saltos extremos que el CBI no usa (0 % de 1:3 o 3:1).

## Tabla comparativa de las 5 aproximaciones

| Aspectos | Ap. 5 | Ap. 6 | Ap. 7 | Ap. 8 | Ap. 9 |
|----------|-------|-------|-------|-------|-------|
| Duración | lineal | log | log | log | **log + WTC rhythm** |
| Coste armónico | voraz | voraz | lookahead×1 | WTC (3ras/6tas) | WTC (3ras/6tas) |
| Coste melódico | — | — | semitono/tritono | **wtcMelodicCost** | **wtcMelodicCost** |
| Resolución de salto | — | — | — | **sí** | **sí** |
| Movimiento contrario | — | — | leve | **bonus activo** | **bonus activo** |
| Lookahead | 0 | 0 | +1 | +2 | +2 |
| Runs rítmicos | no | no | no | no | **sí** |
| Tope 2:1 | no | no | no | no | **sí** |

## Parámetros

| Parámetro | Valor |
|---|---|
| Tempo | 72 BPM |
| PPQ | 480 ticks/beat |
| Instrumentos | S+A+T: Grand Piano (GM 0) · B: Contrabass (GM 43) |
| Secuencia | MiniABC (234 bases → 231 tetranucleótidos solapados) |

## Generación

```bash
perl script/generar_midi_aprox9.pl
```

---

## prueba1

- **Surcos:** major groove (Soprano+Alto) + minor groove (Tenor+Bajo)
- **Voces:** 4 (SATB), formato MIDI 1, 5 pistas
- **Algoritmo:** WTC rhythm + WTC voice leading (Bach CBI-informed, completo)
