# Aproximación 3

**Pitch:** `ocupación (%) × 10 → Hz → nota más cercana en escala temperada`
**Duración:** tiempo de vida media → figura más cercana (80 ticks/ps, negra = 6 ps = 480 ticks)
**Lectura:** tetranucleótidos solapados con paso 1 → 231 notas

Mapeo de duraciones:
| Tiempo de vida media | Figura | Ticks |
|---|---|---|
| ~3 ps | Corchea (♪) | 240 |
| ~4.5 ps | Corchea con punto | 360 |
| ~6 ps | Negra (♩) | 480 |
| ~9 ps | Negra con punto | 720 |
| ~12 ps | Blanca (𝅗𝅥) | 960 |

Rangos reales: major 3.27–10.31 ps, minor 3.36–11.81 ps.

**Secuencia:** misma que aprox1/2 (234 bases → 231 tetranucleótidos solapados).

---

## prueba1

- **Surcos:** major groove (canal 1) + minor groove (canal 2)
- **Pistas:** 2 (MIDI formato 1)
- **Duración:** cada pista usa su propio tiempo de vida media → se dessincronizan a lo largo de la pieza

**Distribución de figuras — Major groove:**
| Figura | Notas |
|---|---|
| Corchea | 38 |
| Corchea con punto | 92 |
| Negra | 72 |
| Negra con punto | 29 |

**Distribución de figuras — Minor groove:**
| Figura | Notas |
|---|---|
| Corchea | 5 |
| Corchea con punto | 110 |
| Negra | 87 |
| Negra con punto | 26 |
| Blanca | 3 |

---

## prueba2

- **Surcos:** major + minor groove como acordes simultáneos
- **Pistas:** 1 (major en canal 1, minor en canal 2, onset idéntico)
- **Duración compartida:** promedio de los dos tiempos de vida media → figura más cercana

El promedio concentra la distribución y elimina los extremos (desaparecen las blancas).

**Distribución de figuras (promedio major+minor):**
| Figura | Notas |
|---|---|
| Corchea | 1 |
| Corchea con punto | 100 |
| Negra | 125 |
| Negra con punto | 5 |
