# Aproximación 11

**S como melodía principal: arco planificado con reglas de intervalo y salto**

## Concepto

La voz Soprano se genera como una **melodía en arco planificada** en lugar de tomarse directamente de mg_midi. Los datos del surco mayor siguen informando la SELECCIÓN de alturas (rawTargets) y las DURACIONES (mg_ticks), pero la conducción melódica responde a reglas musicales estrictas. Las voces A, T y B conservan la conducción de voces WTC (Aproximación 8).

## Reglas de la melodía en S

### Intervalos permitidos
| Intervalo | Semitonos |
|-----------|-----------|
| 2ª menor | 1 |
| 2ª mayor | 2 |
| 3ª menor | 3 |
| 3ª mayor | 4 |
| 4ª justa | 5 |
| 5ª justa | 7 |
| 6ª menor | 8 |
| 6ª mayor | 9 |
| 8ª justa | 12 |

*No se usan: unísono, tritono (6 st), 7ª menor (10 st), 7ª mayor (11 st).*

### Arco melódico (punto álgido)
- La melodía asciende desde la primera nota hasta el **punto álgido** (climax)
- El punto álgido se sitúa en aproximadamente el **60 %** de la secuencia
- El punto álgido es el percentil 75 de las notas disponibles en el registro de Soprano
- Después del punto álgido, la melodía **desciende** hasta el final
- El punto álgido **no se repite**

### Saltos (movimiento disjunto)
- **Entre 2 y 4 saltos totales** (intervalos > M2)
- **Máximo 2 saltos mayores de 4ª justa** (P5, m6, M6, P8 ≥ 7 semitonos)

### Reglas de conducción tras salto
| Tipo de salto | Regla |
|---------------|-------|
| 3ª menor o mayor (3–4 st) | Puede continuar en el mismo sentido |
| 4ª justa o mayor (≥ 5 st) | **Debe** cambiar de sentido, preferiblemente por grado conjunto |
| Cualquier salto | Evitar dos saltos consecutivos en la misma dirección |
| — | No más de 2 saltos consecutivos en general |

## Voces A, T, B

Conducción WTC (Aproximación 8):
- `wtcMelodicCost`: grado conjunto preferido (M2/m2 = 0)
- `wtcHarmonicCost`: 3ras/6tas primero; P4 penalizado
- Resolución de salto, movimiento contrario, lookahead × 2
- Roles: T = Fix, B = surco menor (dato) — mismo que aprox 8

## Algoritmo `generateSopranAprox11`

```
1. Calcular rawTargets[] = mg_midi snap → escala → registro S
2. Fijar climaxPos = round(N × 0.60)
3. Fijar climaxNote = sScale[⌊|sScale| × 0.75⌋]
4. Generar nota a nota:
   - Fase ascendente (0 → climaxPos-1): filtrar candidatos que no superen climaxNote
   - En climaxPos: colocar climaxNote (nota más cercana alcanzable)
   - Fase descendente (climaxPos+1 → N-1): filtrar candidatos < climaxNote
   - En cada paso: aplicar restricciones de intervalo, saltos y sentido
   - Puntuar: grado conjunto preferido, dirección de fase, proximidad a rawTarget
```

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
