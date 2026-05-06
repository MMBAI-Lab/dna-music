# Aproximación 11

**Voces internas A y B como melodías en arco — textura contrapuntística bachiana**

## Base

Aprox 11 hereda la asignación de voces de **aprox10/prueba2**:

| Voz | Fuente | Registro |
|-----|--------|----------|
| Soprano | Surco mayor (dato) | D4–D6 |
| Alto | **Fix — arco ap11** | G3–C5 |
| Tenor | Surco menor (dato) | C3–G4 |
| Bajo | **Fix — arco ap11** | D2–D4 |

## La diferencia: A y B como melodías en arco

En lugar de generarse solo como relleno armónico, cada voz fix tiene una **curva melódica planificada**:
- Asciende hacia un punto álgido (~60% de la secuencia)
- Desciende desde el punto álgido hasta el final
- Los dos arcos están coordinados: el climax de A y el de B ocurren en la misma posición

### Intervalos permitidos
m2 · M2 · m3 · M3 · P4 · P5 · m6 · M6 · P8  
*(Sin unísonos, tritonos ni séptimas)*

### Reglas de salto
| Condición | Regla |
|-----------|-------|
| Saltos totales (>M2) | Entre 2 y 4 |
| Saltos > P4 | Máximo 2 |
| Tras salto > M3 | Cambiar de sentido obligatorio (pref. grado conjunto) |
| Tras 3ª (m3/M3) | Puede continuar en el mismo sentido |
| Saltos consecutivos misma dirección | Evitar |
| Saltos consecutivos en general | Máximo 2 |

### Arco: restricciones de registro dinámico
- A debe estar en todo momento **entre T y S** (T < A < S)
- B debe estar en todo momento **por debajo de T** (B < T)
- El punto álgido de A es el percentil 80 de las notas de A disponibles en climaxPos
- El punto álgido de B es el percentil 80 de las notas de B disponibles en climaxPos

## Puntuación combinada

Para cada nota candidata se evalúan simultáneamente:

1. **Coste de intervalo** — pasos: 0; 3ras: +4; P4: +7; ≥P5: +11
2. **Dirección de fase** — premio −5 si va en el sentido del arco; penalización +7 si va en contra
3. **Coste armónico WTC** — `wtcHarmonicCost(note, T)` × 1.5 + lookahead × 2 pasos
4. **Movimiento contrario** — bonus −4 si A va en dirección opuesta a S, o B opuesta a T
5. **Atracción al centro de registro** — penalización leve por alejarse del centro
6. **Incentivo al arco** — durante la fase ascendente, pull hacia climaxNote; al final, preferir notas bajas

## Por qué esto suena más a Bach

1. Cada voz tiene su propia **línea melódica con forma**, no solo acordes
2. El **movimiento contrario** entre voces adyacentes crea independencia polifónica
3. La preferencia por **grado conjunto** refleja el 70% stepwise de las fugas del WTC
4. Los **intervalos armónicos** privilegian 3ras y 6tas (coste WTC) — el color characteristic de Bach
5. Los **arcos coordinados** crean una arquitectura dinámica hacia el punto álgido global

## Pruebas

| Prueba | Descripción |
|--------|-------------|
| prueba1 | Paleta libre (5 figuras), sin compás explícito |
| prueba2 | Paleta 4/4 {corchea, negra, blanca} + meta-evento 4/4 |

## Generación

```bash
perl script/generar_midi_aprox11.pl    # prueba1
perl script/generar_midi_aprox11p2.pl  # prueba2 (4/4)
```
