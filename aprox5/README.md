# Aproximación 5 — Transformación estilo Bach (Contrapunctus 1)

Aplicación de restricciones estilísticas del Contrapunctus 1 de La Arte de la Fuga (J.S. Bach) sobre los datos de ADN. No genera estructura fugal real (sujeto/respuesta/episodios), sino que impone las características tonales, de registro y de movimiento melódico propias de esa obra.

**CSVs de mapeo (en `data/`):**
- `notas_256_majorgroove_aprox5.csv` — columnas: `tetranucleotide`, `canonico`, `nota_original`, `nota_aprox5`, `midi_aprox5`, `voz`
- `notas_256_minorgroove_aprox5.csv` — ídem para minor groove (voz = bajo, D2–D4)

**Transformaciones aplicadas:**

1. **Tonalidad:** todas las notas quantizadas a Re menor natural (D, E, F, G, A, Bb, C) — cada nota cromática se mueve al grado más cercano de la escala
2. **Registro separado por voz:**
   - Major groove → soprano: D4–D6 (centro A4), voz superior
   - Minor groove → bajo: D2–D4 (centro D3), voz inferior
3. **Voice leading:** si el salto entre notas consecutivas supera 7 semitonos, se invierte una octava (siempre que quede dentro del registro)
4. **Duración:** normalización lineal del tiempo de vida media sobre el rango real de cada surco → 5 figuras (igual que aprox4)
5. **Tempo:** 72 BPM (♩ = 833333 µs), más lento que las aprox anteriores (120 BPM)

**Secuencia:** misma que aprox1–4 (234 bases → 231 tetranucleótidos solapados, paso 1).

---

## prueba1

- **Surcos:** major groove (soprano, canal 1) + minor groove (bajo, canal 2), pistas independientes
- **Pistas:** 2 (MIDI formato 1)
- **Notas:** 231 por voz

**Distribución de figuras — Soprano (major groove):**
| Figura | Notas |
|---|---|
| Corchea | 99 |
| Corchea con punto | 67 |
| Negra | 36 |
| Negra con punto | 20 |
| Blanca | 9 |

**Distribución de figuras — Bajo (minor groove):**
| Figura | Notas |
|---|---|
| Corchea | 89 |
| Corchea con punto | 102 |
| Negra | 19 |
| Negra con punto | 18 |
| Blanca | 3 |

**Notas sobre el resultado:**
- La quantización a Re menor elimina toda la cromaticidad del mapeo original
- El registro separado crea una textura de dos voces con espacio entre ellas
- El voice leading suaviza los saltos más abruptos pero no elimina todos los movimientos no-bachinianos

---

## prueba2 — 4 voces SATB con notas de corrección

Amplía prueba1 con dos voces de corrección armónica (alto y tenor), análogas a las "notas en negro" de la partitura original.

**Estructura de voces:**
| Voz | Fuente | Registro | Canal |
|---|---|---|---|
| Soprano | Major groove (datos) | D4–D6 | 0 |
| Alto | Generada (corrección) | G3–C5 | 1 |
| Tenor | Generado (corrección) | C3–G4 | 2 |
| Bajo | Minor groove (datos) | D2–D4 | 3 |

**Reglas aplicadas:**

- **R1–R3** (heredadas de prueba1): snap a Re menor, forzar registro, voice leading ≤7st
- **R4**: Alto y tenor usan exclusivamente grados de Re menor natural
- **R5 — Generación del Alto** [G3–C5]: se elige el grado de Re menor que minimiza `movimiento_desde_anterior + 15×(disonante_con_bajo) + 5×(menos_de_3st_de_soprano)`; debe estar estrictamente por debajo de soprano
- **R6 — Generación del Tenor** [C3–G4]: minimiza `movimiento + 15×(disonante_con_bajo)`; debe estar entre bajo y alto. Si no hay posición válida (cruce inevitable), toma la mediana del espacio disponible
- **R7**: Paralelismos 5as/8as entre Soprano–Bajo → mover soprano un grado arriba en la escala
- **R8**: Paralelismos 5as/8as entre Soprano–Alto → mover alto un grado abajo
- **R9 — Duraciones independientes por dúo** ⭐ **Resultado muy satisfactorio**: Soprano+Alto comparten duración (major groove); Tenor+Bajo comparten duración (minor groove) → dos dúos rítmicamente independientes

**Nota**: la corrección de paralelismos (R7) puede introducir nuevas disonancias al mover la soprano; las disonancias S–B pasaron de 88 a 91 (ligero aumento esperado). Las voces de corrección (A y T) sí reducen la percepción de disonancia al rellenar el espacio armónico.

---

## prueba3 — Secuencia ADN diseñada para aproximar Contrapunctus 1

En lugar de usar la secuencia fija de las pruebas anteriores, aquí se **busca la secuencia de ADN** que mejor reproduce la melodía del Contrapunctus 1.

**Estrategia (búsqueda greedy):**
1. Definir melodía objetivo: sujeto del Contrapunctus 1 desarrollado (~149 notas, ~1:53 min)
2. Para cada uno de los 256 tetranucleótidos, precalcular la nota soprano resultante (snap Re menor → D4–D6)
3. Construir grafo de adyacencia: ABCD puede ir seguido de BCDA/C/G/T (4 sucesores)
4. En cada paso, de los 4 posibles sucesores, elegir el que produce la nota más cercana al objetivo
5. Reconstruir la secuencia de ADN a partir del camino recorrido

**Melodía objetivo — sujeto y desarrollo:**
- Sujeto (Re menor): D5 A4 F4 G4 A4 Bb4 A4 G4 F4 E4 D4 (×2)
- Respuesta (en La): A4 E4 C5 D5 E5 F5 E5 D5 C5 Bb4 A4 (×2)
- Secuencias descendente y ascendente
- Inversión del sujeto, desarrollo, cadencia final

**Resultado:**
- Secuencia ADN: 152 bases, 149 tetranucleótidos
- Error promedio: 2.44 semitonos
- 30 notas exactas (0 st), 18 a 1 st, 33 a 2 st, 22 a 3 st, 17 a 4 st, 29 a 5 st
- Archivos: `prueba3.mid` + `prueba3_secuencia.dat` (secuencia con tabla de comparación objetivo/logrado)

**Valoración:** resultado insatisfactorio. La búsqueda greedy tiende a reutilizar siempre los mismos tetranucleótidos (los que tienen notas centrales del registro D4–D6), generando poca variedad rítmica y melódica. La secuencia diseñada algorítmicamente pierde la riqueza que surge de usar una secuencia de ADN real.
