# Aproximación 6 — Blues/Jazz (La Dorian, swing)

**Valoración:** resultado insatisfactorio. Suena demasiado rápida y no logra el feel jazz/blues buscado. Se sigue prefiriendo aprox5/prueba2. Posibles causas: 108 BPM es demasiado veloz para la densidad de notas generada por los tetranucleótidos solapados; el swing 2:1 en MIDI no es suficiente sin un contexto armónico de acordes de séptima; La Dorian sola no basta para sonar jazz sin fraseo idiomático.

Basada en aprox5/prueba2 (4 voces SATB con corrección armónica), con las siguientes modificaciones:

**Escala: La Dorian** (A, B, C, D, E, F#, G)
- Cromas: 0, 2, 4, 6, 7, 9, 11
- Escala modal característica del jazz y blues moderno: Miles Davis "So What", John Coltrane, etc.
- El F# le da el sabor lydian/jazz frente al F natural del Re menor de aprox5

**Registros** (centrados en La en vez de Re):
| Voz | Fuente | Registro | Centro |
|---|---|---|---|
| Soprano | Major groove (datos) | A4–A6 [69–93] | E5 (76) |
| Alto | Corrección | D4–G5 [62–79] | A4 (69) |
| Tenor | Corrección | G3–D5 [55–74] | D4 (62) |
| Bajo | Minor groove (datos) | A2–A4 [45–69] | E3 (52) |

**Tempo:** 108 BPM (medium swing)

**Swing:** corcheas ejecutadas en ratio 2:1
- Pares de corcheas consecutivas: larga (320 ticks) + corta (160 ticks)
- Notas de negra o más largas: sin swing (se resetea el par)
- Produce el "lilt" característico del jazz

**Reglas de corrección armónica:** idénticas a aprox5/prueba2 (R4–R9)

**CSVs de mapeo:**
- `data/notas_256_majorgroove_aprox6.csv`
- `data/notas_256_minorgroove_aprox6.csv`

---

## prueba1

- **Surcos:** major groove (soprano) + minor groove (bajo), con alto y tenor como corrección
- **Pistas:** 5 (tempo + SATB)
- **Notas:** 231 por voz
- **Escala:** La Dorian

**Distribución de duraciones — Soprano (tras swing):**
| Duración | Notas |
|---|---|
| Corchea larga (swing, 320t) | 76 |
| Corchea con punto (360t) | 67 |
| Negra (480t) | 36 |
| Negra con punto (720t) | 20 |
| Blanca (960t) | 9 |
| Corchea corta (swing, 160t) | 23 |
