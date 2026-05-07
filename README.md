# ABC Música - Dans & Molla

Proyecto de sonificación de ADN: mapeo de dinámicas moleculares de los surcos del ADN (major y minor groove) a parámetros musicales.

Los datos provienen de simulaciones de dinámica molecular sobre todos los tetranucleótidos únicos (136, considerando simetría de complemento inverso). Para cada tetranucleótido se dispone de cuatro métricas: entradas, frecuencia de entrada, tiempo de vida media y ocupación.

La escala musical utilizada es la escala temperada cromática C1–C7 (84 notas).

---

## Aplicación web (`interface/`)

Interfaz Next.js desplegada en **https://mmbai-lab.github.io/dna-music/**.  
Permite pegar una secuencia de ADN y generar música en el navegador (sin servidor).

**Controles disponibles:**
- Secuencia de ADN (A/T/C/G, máx. 200 bases)
- **KEY** — 12 tonalidades: menores naturales, mayores, modos, pentatónicas, doble armónica (Re Bizant.), octatónica disminuida · Toggle Tonal/Cromático para usar las alturas crudas del dato
- **Algorithm** — selector rotativo (rocker) para elegir Aproximación 5–11
- **Meter** — toggle Libre / 4/4 (cuantiza figuras + meta-evento MIDI)
- **Volume Mix** — 4 faders independientes (Soprano/Alto/Tenor/Bajo) con etiquetas de origen
- **Tempo** — knob 30–240 BPM
- Botones ▶ Reproducir / ⏮ Reiniciar / ■ Detener / ⬇ Descargar MIDI

Deploy automático vía GitHub Actions al hacer push a `main`.

---

## Archivos de datos (`data/`)

| Archivo | Descripción |
|---|---|
| `notas_cromaticas_C1_a_C7.csv` | Escala cromática C1–C7 con frecuencias en Hz |
| `notas_256_majorgroove_aprox1_2.csv` | 256 tetranucleótidos → nota (major, escala cromática) |
| `notas_256_minorgroove_aprox1_2.csv` | 256 tetranucleótidos → nota (minor, escala cromática) |
| `notas_256_majorgroove_aprox3_6.csv` | Añade columnas de duración: aprox4 (lineal) y aprox6 (logarítmica) |
| `notas_256_minorgroove_aprox3_6.csv` | Ídem para minor groove |

**Tablas para la app web** (`interface/public/tables.json`): 256 entradas con `mg_midi`, `mg_ticks_lin`, `mg_ticks_log`, `mn_midi`, `mn_ticks_lin`, `mn_ticks_log`. Generadas con `script/generar_tables_json.ps1`.

**Corpus WTC** (`source/wtc1_xml/`): 24 archivos MusicXML del Clave Bien Temperado Libro I de Bach (BWV 846–869), analizados para derivar las funciones de coste de las Aproximaciones 8–11.

**Secuencia usada en todas las pruebas:**
```
GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGG
ACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGC
GCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC
```
234 bases → 231 tetranucleótidos solapados.

---

## Aproximación 1 — Pitch desde ocupación, tetranucleótidos no solapados

**Pitch:** `ocupación (%) × 10 → Hz → nota más cercana en escala temperada`  
**Duración:** negra fija (♩), 120 BPM  
**Lectura:** tetranucleótidos no solapados (paso 4) → 58 notas

| Prueba | Surcos | Pistas | Notas |
|--------|--------|--------|-------|
| prueba1 | major groove | 1 | 58 |
| prueba2 | major + minor simultáneos | 2 | 58 |

---

## Aproximación 2 — Pitch desde ocupación, tetranucleótidos solapados (paso 1)

**Pitch:** igual que aprox1  
**Duración:** negra fija (♩), 120 BPM  
**Lectura:** tetranucleótidos solapados → 231 notas

| Prueba | Surcos | Pistas | Notas |
|--------|--------|--------|-------|
| prueba1 | major + minor simultáneos | 2 | 231 |
| prueba2 | major + minor intercalados | 1 | 462 |

---

## Aproximación 3 — Pitch desde ocupación + duración desde tiempo de vida media

**Pitch:** igual que aprox1/2  
**Duración:** tiempo de vida media → figura más cercana (80 ticks/ps, negra = 6 ps)

| Tiempo de vida media | Figura | Ticks |
|---|---|---|
| ~3 ps | Corchea (♪) | 240 |
| ~4.5 ps | Corchea con punto | 360 |
| ~6 ps | Negra (♩) | 480 |
| ~9 ps | Negra con punto | 720 |
| ~12 ps | Blanca (𝅗𝅥) | 960 |

| Prueba | Descripción | Pistas |
|--------|-------------|--------|
| prueba1 | major + minor, pistas independientes (se dessincronizan) | 2 |
| prueba2 | acordes major+minor, duración = promedio | 1 |

---

## Aproximación 4 — Pitch desde ocupación + duración por normalización lineal

**Duración:** rango real dividido en 5 segmentos iguales → figura por segmento.

| Prueba | Descripción | Pistas |
|--------|-------------|--------|
| prueba1 | major + minor, pistas independientes | 2 |

---

## Aproximación 5 — 4 voces SATB, Re menor, normalización lineal

Restricciones estilísticas: tonalidad Re menor natural, registros SATB, voice leading (saltos > 7 st → inversión por octava), coste greedy (movimiento + disonancia + espaciado), corrección post-hoc de paralelismos S–A (R8).

**Roles de voces:** S = surco mayor (dato) · A = Fix · T = Fix · B = surco menor (dato)

| Prueba | Descripción |
|--------|-------------|
| prueba1 | Soprano + Bajo de datos, Re menor 72 BPM |
| prueba2 ⭐ | 4 voces SATB: S+B de datos, A+T generados, Grand Piano + Contrabajo |
| prueba3 | Secuencia diseñada algorítmicamente para aproximar el Contrapunctus 1 |

---

## Aproximación 6 — Normalización logarítmica de duración

Igual que aprox5/prueba2 pero con normalización logarítmica del tiempo de vida media, que redistribuye mejor la distribución de figuras hacia valores más largos.

| Prueba | Descripción |
|--------|-------------|
| prueba1 | SATB, log, 72 BPM |
| prueba2 | + clarinete soprano, correcciones armónicas |
| prueba3 | Grand Piano (S+A+T) + Contrabajo (B) |

---

## Aproximación 7 — Lookahead +1

Rediseño del algoritmo de voces fix para que sea **universalmente aplicable**. Al generar la nota de corrección en posición i, se conoce el bajo de la posición i+1 (lookahead) y se elige la nota que minimiza la disonancia tanto en i como en i+1.

**Función de coste (Alto y Tenor):**

| Penalización | Peso |
|---|---|
| Suavidad (movimiento, cap 6 st) | ×1 |
| Semitono cromático | ×12 |
| Tritono | ×5 |
| Disonancia con Bajo [i] | ×15 |
| Disonancia con Bajo [i+1] (lookahead) | ×8 |
| Proximidad a Soprano (< 3 st, solo Alto) | ×5 |
| Paralelismos 5as/8as S–A y B–T | ×20 |
| Movimiento paralelo a Soprano | ×3 |
| Nota repetida | ×3 |
| Deriva del centro de registro | ×1 |

| Prueba | Descripción |
|--------|-------------|
| prueba1 | Re menor, 72 BPM, Grand Piano + Contrabajo |

---

## Aproximación 8 — Conducción de voces informada por el CBI de Bach

Análisis del corpus del **Clave Bien Temperado Libro I** (24 archivos MusicXML, BWV 846–869, 43 233 notas):
- ~70 % de los intervalos melódicos en fugas son M2 o m2 (grado conjunto)
- Intervalos armónicos característicos: terceras (m3/M3) y sextas (m6/M6)
- Resolución de salto: los saltos ≥ P4 van seguidos de un paso en dirección contraria

**Funciones de coste nuevas:**
- `wtcMelodicCost`: M2/m2 = 0 (libres); P4 = 9; P5+ = 15/24
- `wtcHarmonicCost`: m3/M3 = 0; m6/M6 = 1; P4 = 7 (disonante en voces internas); P5 = 4; tritono = 20
- `leapResolutionCost`: penalización si dos saltos consecutivos van en la misma dirección
- Bonus activo de movimiento contrario S–A (−5) y T–B (−4)
- **Lookahead × 2 pasos**

| Prueba | Descripción |
|--------|-------------|
| prueba1 | Re menor, 72 BPM, Grand Piano + Contrabajo |

---

## Aproximación 9 — Normalización rítmica WTC + conducción Bach

Añade a la conducción de voces de Aprox 8 un **post-procesado rítmico** derivado del análisis del corpus WTC:
- 72.5 % de las transiciones rítmicas son 1:1 (misma figura)
- 0 % de saltos de figura > 2:1 (nunca salta de corchea a blanca directamente)

**Algoritmo `applyWTCRhythm`:**
1. Snap a paleta de 5 figuras (log)
2. Homogeneización de runs: figuras adyacentes (ratio ≤ 1.5) se elevan a la mayor
3. Tope 2:1: cualquier transición mayor se recorta

| Prueba | Descripción |
|--------|-------------|
| prueba1 | WTC rhythm + conducción Bach, paleta libre |
| prueba2 | + paleta 4/4 {♪ ♩ 𝅗𝅥} + meta-evento de compás |
| prueba3 | prueba1 con Tenor +15ma (2 octavas arriba en la salida MIDI) |

---

## Aproximación 10 — Inversión de roles T/B

**Cambio de asignación de voces:**

| Voz | Aprox 5–9 | Aprox 10 |
|-----|-----------|----------|
| Soprano | Surco mayor (dato) | Surco mayor (dato) |
| Alto | Fix | Fix |
| **Tenor** | Fix | **Surco menor (dato)** |
| **Bajo** | Surco menor (dato) | **Fix** |

T toma mn_midi en el registro Tenor (C3–G4). B se genera por debajo de T usando `wtcHarmonicCost`. A se genera entre T y S con T como referencia armónica. R7 aplicado a S–T en lugar de S–B.

| Prueba | Descripción |
|--------|-------------|
| prueba1 | Inversión T/B, paleta libre |
| prueba2 | + paleta 4/4 + meta-evento de compás |

---

## Aproximación 11 — Voces internas como melodías en arco (textura bachiana)

Base: inversión T/B de Aprox 10. **Novedad**: A y B se generan como **melodías en arco planificadas** con identidad melódica propia, en lugar de ser solo relleno armónico.

**Reglas de arco (A y B, coordinados al ~60 % de la secuencia):**

| Regla | Valor |
|---|---|
| Intervalos permitidos | m2 M2 m3 M3 P4 P5 m6 M6 P8 |
| Punto álgido | Percentil 80 de las notas factibles en climaxPos |
| El punto álgido no se repite | — |
| Saltos totales (> M2) | 2–4 |
| Saltos > P4 | Máximo 2 |
| Tras salto > M3 | Cambio de sentido obligatorio (pref. grado conjunto) |
| Tras 3ª (m3/M3) | Puede continuar mismo sentido |
| Saltos consecutivos misma dirección | Evitar |
| Saltos consecutivos en general | Máximo 2 |

A está siempre entre T y S (T < A < S). B está siempre por debajo de T (B < T).

**Puntuación:** coste de intervalo + dirección de arco + `wtcHarmonicCost` con T (lookahead × 2) + bonus movimiento contrario vs voz adyacente + atracción al centro de registro.

**Por qué suena más a Bach:** cada voz tiene una línea melódica con forma (no solo acordes), el movimiento contrario crea independencia polifónica, el grado conjunto predomina y las 3ras/6tas armónicas dan el color tonal bachiano.

| Prueba | Escala A/B | Descripción |
|--------|-----------|-------------|
| prueba1 | Re menor | Paleta libre, 5 figuras |
| prueba2 | Re menor | Paleta 4/4 + meta-evento de compás |
| prueba3 | **Re mayor** | A y B en Re mayor (D E F# G A B C#) con filtro de consonancia estricto: candidatos filtrados para ser consonantes con T y S. Fallback progresivo si no hay opción completamente consonante. Las estadísticas de salida muestran disonancias para los 5 pares de voces (S–T, S–A, A–T, A–B, B–T). |

---

## Resumen de scripts

| Script | Aprox | Descripción |
|--------|-------|-------------|
| `generar_midi_aprox3.pl` | 3 | 2 pistas: major + minor |
| `generar_midi_aprox3p2.pl` | 3 | Acordes major+minor |
| `generar_midi_aprox4.pl` | 4 | Normalización lineal |
| `generar_midi_aprox5.pl` | 5 | 4 voces SATB básico |
| `generar_midi_aprox5p2.pl` | 5 | Corrección armónica greedy |
| `generar_midi_aprox5p3.pl` | 5 | Variante |
| `generar_midi_aprox6.pl` | 6 | Log normalización |
| `generar_midi_aprox6p2.pl` | 6 | + clarinete |
| `generar_midi_aprox6p3.pl` | 6 | Grand Piano + Contrabajo |
| `generar_midi_aprox7.pl` | 7 | Lookahead +1 |
| `generar_midi_aprox8.pl` | 8 | WTC voice leading |
| `generar_midi_aprox9.pl` | 9 | WTC rhythm + voice leading |
| `generar_midi_aprox9p2.pl` | 9 | + 4/4 |
| `generar_midi_aprox9p3.pl` | 9 | Tenor +15ma |
| `generar_midi_aprox10.pl` | 10 | T/B role swap |
| `generar_midi_aprox10p2.pl` | 10 | + 4/4 |
| `generar_midi_aprox11.pl` | 11 | A y B en arco, Re menor |
| `generar_midi_aprox11p2.pl` | 11 | + 4/4 |
| `generar_midi_aprox11p3.pl` | 11 | A y B en Re mayor, consonancia estricta |
