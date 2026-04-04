# Aproximación 4

**Pitch:** `ocupación (%) × 10 → Hz → nota más cercana en escala temperada`
**Duración:** normalización lineal del tiempo de vida media sobre el rango real de cada surco → 5 figuras
**Lectura:** tetranucleótidos solapados con paso 1 → 231 notas
**Pistas:** major y minor groove independientes (se dessincronizan)

El rango real de cada surco se divide en 5 segmentos iguales, mapeando así todo el espectro de valores disponibles:

| Segmento | Figura | Ticks |
|---|---|---|
| 1 (más corto) | Corchea (♪) | 240 |
| 2 | Corchea con punto | 360 |
| 3 | Negra (♩) | 480 |
| 4 | Negra con punto | 720 |
| 5 (más largo) | Blanca (𝅗𝅥) | 960 |

Rangos reales: major 3.271–10.306 ps, minor 3.355–11.808 ps. Cada surco normaliza contra su propio rango.

**Secuencia:** misma que aprox1–3 (234 bases → 231 tetranucleótidos solapados).

---

## prueba1

- **Surcos:** major groove (canal 1) + minor groove (canal 2), pistas independientes
- **Pistas:** 2 (MIDI formato 1)

**Distribución de figuras — Major groove:**
| Figura | Notas |
|---|---|
| Corchea | 99 |
| Corchea con punto | 67 |
| Negra | 36 |
| Negra con punto | 20 |
| Blanca | 9 |

**Distribución de figuras — Minor groove:**
| Figura | Notas |
|---|---|
| Corchea | 89 |
| Corchea con punto | 102 |
| Negra | 19 |
| Negra con punto | 18 |
| Blanca | 3 |

Nota: la distribución sigue sesgada hacia figuras cortas porque los tiempos de vida media se concentran en la parte baja del rango real. Una distribución más uniforme requeriría una normalización no lineal (por ejemplo, por cuartiles o por rango intercuartílico).
