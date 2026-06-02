# Aproximación 12

**3 voces triádicas: tríada mayor o menor anclada en la nota más grave**

## Concepto

Aprox 12 reduce la textura a **3 voces** generando, para cada tetranucleótido,
una tríada mayor o menor completa a partir de los dos datos del surco.

| Voz | Fuente | Registro | Duración |
|-----|--------|----------|----------|
| Soprano | Surco mayor (dato) | D4–D6 | mg_ticks_log |
| **Alto** | **Silenciada** (panel bloqueado) | — | — |
| Tenor | **3ª nota calculada** | D2–D6 (entre B y S) | mn_ticks_log |
| Bajo | Surco menor (dato) | D2–D4 | mn_ticks_log |

## Algoritmo `findTriadThird`

1. Identificar la nota más grave del par (B = mn_midi) y la más aguda (S = mg_midi).
2. Buscar en las 24 tríadas (12 mayores + 12 menores) las que contienen el pitch class del bajo.
3. Si alguna también contiene el pitch class de la soprano → **coincidencia exacta**: la 3ª nota es el pitch class restante.
4. Si no → **aproximación**: encontrar la tríada que minimiza la distancia cromática a la soprano, anchada en el bajo.
5. Elegir la octava de la 3ª nota que la coloca en el punto medio entre bajo y soprano (rango D2–D6).

**Estabilidad preferida:** estado fundamental (bajo = raíz) > 2ª inversión (bajo = quinta) > 1ª inversión (bajo = tercera).

## Duraciones

- Soprano: `mg_ticks_log` (normalización logarítmica del surco mayor)
- Tenor (3ª nota) y Bajo comparten `mn_ticks_log` — la 3ª nota hereda la figura del bajo

## Interfaz web

Al seleccionar Aproximación 12, el fader de **Alto se desactiva automáticamente** (bloqueado en 0, griseado). Solo son operativos los faders de Soprano, Tenor y Bajo.

## Pruebas

| Prueba | Descripción | Secuencia |
|--------|-------------|-----------|
| ACCG_triadas_v1–v3 | Pruebas de desarrollo | ACCGCGGAGTCGTTTAGTGCGTGCGTGT (28 nt) |
| ACCG_triadas_v4 | Versión final: tríada desde nota grave, 3ª nota = figura del bajo | ACCGCGGAGTCGTTTAGTGCGTGCGTGT (28 nt) |
| insulina_INS_triadas_v4 | Misma lógica sobre gen insulina | INS humano, primeros 200 nt |
| insulina_INS_aprox8 | SATB 4 voces sobre gen insulina | INS humano, primeros 200 nt |

## Generación

```bash
perl script/generar_midi_aprox12.pl    # prueba1 (paleta libre)
perl script/generar_midi_aprox12p2.pl  # prueba2 (4/4)
```
