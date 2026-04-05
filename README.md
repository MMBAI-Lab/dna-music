# ABC Música Molla

Proyecto de sonificación de ADN: mapeo de dinámicas moleculares de los surcos del ADN (major y minor groove) a parámetros musicales.

Los datos provienen de simulaciones de dinámica molecular sobre todos los tetranucleótidos únicos (140, considerando simetría de complemento inverso). Para cada tetranucleótido se dispone de cuatro métricas: entradas, frecuencia de entrada, tiempo de vida media y ocupación.

La escala musical utilizada es la escala temperada cromática C1–C7 (84 notas).

## Archivos de datos (`data/`)

| Archivo | Descripción |
|---|---|
| `notas_cromaticas_C1_a_C7.csv` | Escala cromática C1–C7 con frecuencias en Hz (3 decimales) |
| `notas_140_majorgroove.csv` | 140 tetranucleótidos canónicos → nota (aprox1/2, major) |
| `notas_140_minorgroove.csv` | 140 tetranucleótidos canónicos → nota (aprox1/2, minor) |
| `notas_256_majorgroove_aprox1_2.csv` | 256 tetranucleótidos → nota (aprox1/2, major, escala cromática) |
| `notas_256_minorgroove_aprox1_2.csv` | 256 tetranucleótidos → nota (aprox1/2, minor, escala cromática) |
| `notas_256_majorgroove_aprox3_4.csv` | Añade columnas de duración: aprox3 (valor más cercano) y aprox4 (normalización lineal) |
| `notas_256_minorgroove_aprox3_4.csv` | Ídem para minor groove |
| `notas_256_majorgroove_aprox5.csv` | 256 tetranucleótidos → nota quantizada a Re menor, registro soprano D4–D6 |
| `notas_256_minorgroove_aprox5.csv` | 256 tetranucleótidos → nota quantizada a Re menor, registro bajo D2–D4 |
| `notas_256_majorgroove_aprox3_6.csv` | Extiende aprox3_4 añadiendo columna `aprox6_figura` (normalización logarítmica) |
| `notas_256_minorgroove_aprox3_6.csv` | Ídem para minor groove |

**Secuencia usada en todas las pruebas:**
```
GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGG
ACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGC
GCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC
```
234 bases.

---

## Aproximación 1 — Pitch desde ocupación, tetranucleótidos no solapados

**Pitch:** `ocupación (%) × 10 → Hz → nota más cercana en escala temperada`
**Duración:** negra fija (♩), 120 BPM
**Lectura:** tetranucleótidos no solapados (paso 4) → 58 notas (quedan 2 bases finales `GC` sin usar)

| Prueba | Surcos | Pistas | Notas | Rango |
|--------|--------|--------|-------|-------|
| prueba1 | major groove | 1 | 58 | E3–C#5 |
| prueba2 | major + minor groove simultáneos | 2 | 58 | major: E3–D5 / minor: G1–G#4 |

---

## Aproximación 2 — Pitch desde ocupación, tetranucleótidos solapados (paso 1)

**Pitch:** igual que aprox1
**Duración:** negra fija (♩), 120 BPM
**Lectura:** tetranucleótidos solapados con paso 1 → 231 notas

| Prueba | Surcos | Pistas | Notas | Duración total |
|--------|--------|--------|-------|----------------|
| prueba1 | major + minor groove simultáneos | 2 | 231 | ~1 min 56 s |
| prueba2 | major + minor groove intercalados | 1 | 462 | ~3 min 51 s |

---

## Aproximación 3 — Pitch desde ocupación + duración desde tiempo de vida media

**Pitch:** igual que aprox1/2
**Duración:** tiempo de vida media → figura más cercana (80 ticks/ps, negra = 6 ps)
**Lectura:** tetranucleótidos solapados con paso 1 → 231 notas

Mapeo de duraciones:
| Tiempo de vida media | Figura | Ticks |
|---|---|---|
| ~3 ps | Corchea (♪) | 240 |
| ~4.5 ps | Corchea con punto | 360 |
| ~6 ps | Negra (♩) | 480 |
| ~9 ps | Negra con punto | 720 |
| ~12 ps | Blanca (𝅗𝅥) | 960 |

| Prueba | Surcos | Pistas | Notas | Duración |
|--------|--------|--------|-------|----------|
| prueba1 | major + minor groove, pistas independientes (se dessincronizan) | 2 | 231 | variable |
| prueba2 | acordes major+minor, duración = promedio de ambos tiempos | 1 | 231 | variable |

---

## Aproximación 4 — Pitch desde ocupación + duración por normalización lineal

**Pitch:** igual que aprox1–3
**Duración:** el rango real de tiempo de vida media de cada surco se divide en 5 segmentos iguales → una figura por segmento. Cada surco normaliza contra su propio rango (major: 3.27–10.31 ps, minor: 3.36–11.81 ps).
**Lectura:** tetranucleótidos solapados con paso 1 → 231 notas

| Prueba | Surcos | Pistas | Notas |
|--------|--------|--------|-------|
| prueba1 | major + minor groove, pistas independientes | 2 | 231 |

---

## Aproximación 5 — Transformación estilo Bach (Contrapunctus 1)

Restricciones estilísticas del Contrapunctus 1 (J.S. Bach) aplicadas sobre los datos de ADN:
- Tonalidad: Re menor natural (D E F G A Bb C) — todas las notas quantizadas a la escala
- Registro: major groove → soprano D4–D6 / minor groove → bajo D2–D4
- Voice leading: saltos > 7 semitonos se invierten por octava
- Duración: normalización lineal aprox4
- Tempo: 72 BPM
- CSVs de referencia: `notas_256_majorgroove_aprox5.csv` / `notas_256_minorgroove_aprox5.csv`

| Prueba | Descripción | Pistas | Notas |
|--------|-------------|--------|-------|
| prueba1 | Soprano (major) + Bajo (minor), Re menor, voice leading | 2 | 231 |
| prueba2 ⭐ | 4 voces SATB: S+B de datos, A+T generados como corrección armónica | 5 | 231 |
| prueba3 | Secuencia ADN diseñada para aproximar el Contrapunctus 1 (greedy) | 2 | 149 |

**Valoración:** prueba2 resultó muy satisfactoria. prueba3 sonó monótona — la búsqueda greedy tiende a elegir siempre los mismos tetranucleótidos (los que tienen notas centrales del registro), lo que genera poca variedad rítmica y melódica. La secuencia diseñada algorítmicamente pierde la riqueza que surge de usar una secuencia de ADN real.

---

## Aproximación 6 — Normalización logarítmica de duración

Idéntica a aprox5/prueba2 (4 voces SATB, Re menor, 72 BPM) salvo por el método de asignación de figuras: se sustituye la normalización lineal del tiempo de vida media por una **normalización logarítmica**.

**Motivación:** la normalización lineal concentra valores en corcheas/corcheas con punto porque los tiempos se agrupan en la parte baja del rango. La escala logarítmica redistribuye mejor hacia negras y valores más largos.

| Prueba | Descripción | Pistas | Notas |
|--------|-------------|--------|-------|
| prueba1 | SATB Re menor 72 BPM, duración por normalización logarítmica | 4 | 231 |
| prueba2 | Igual que prueba1 con instrumentos: soprano=clarinete, A+T=piano, bajo=contrabajo | 4 | 231 |
| prueba3 | Igual que prueba2 con soprano también en Grand Piano (S+A+T=piano, B=contrabajo) | 4 | 231 |

---

## Aproximación 7 — Correcciones con anticipación (lookahead)

Rediseño del algoritmo de voces de corrección para hacerlo **universalmente aplicable a cualquier secuencia**: dado el solapamiento de 3 bases entre tetranucleótidos consecutivos, el siguiente estado siempre es conocido de antemano. El algoritmo anticipa la próxima armonía al elegir la nota actual (lookahead +1).

Mejoras principales: penalización de semitonos cromáticos, penalización de tritono (Bb↔E en Re menor), preferencia por movimiento contrario a la soprano, verificación de paralelismos B–T. Resultado: Alto 100% consonante con Bajo en toda la secuencia.

| Prueba | Descripción | Pistas | Notas |
|--------|-------------|--------|-------|
| prueba1 | Lookahead +1, Re menor 72 BPM, Grand Piano + Contrabajo | 4 | 231 |

