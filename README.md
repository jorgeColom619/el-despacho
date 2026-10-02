# EL DESPACHO — Simulador presidencial

Eres el nuevo presidente de la República de Valdoria. Tienes una legislatura para gobernar,
sobrevivir a las crisis, negociar con el mundo y ganar la reelección. Todo ocurre desde tu despacho.

![El despacho](docs/capturas/despacho.png)

| | |
|---|---|
| ![Asesor](docs/capturas/asesor.png) | ![Negociación](docs/capturas/negociacion.png) |
| ![Cumbre internacional](docs/capturas/cumbre.png) | ![Sesión de control](docs/capturas/control.png) |
| ![Campaña por regiones](docs/capturas/campana.png) | ![Fichajes del Gobierno](docs/capturas/fichajes.png) |
| ![Gabinete de crisis](docs/capturas/crisis.png) | ![Congreso](docs/capturas/congreso.png) |
| ![Documentos](docs/capturas/documentos.png) | ![Tienda del Palacio](docs/capturas/tienda.png) |

## Cómo jugar

- Necesitas **[Godot 4.7](https://godotengine.org/download)** (versión estándar, no .NET).
- Abre `project.godot` con Godot y pulsa **F5**. En Windows, si guardas Godot en
  `%USERPROFILE%\Godot\`, basta con hacer doble clic en `Jugar.bat`.
- **F11**: pantalla completa · **Espacio**: pausa · **1 / 2 / 3**: velocidad · **Esc**: menú.
- Usa el renderizador *Compatibility*, así que funciona incluso en equipos sin tarjeta gráfica dedicada.

## El despacho (todo es interactivo)

| Objeto | Qué hace |
|---|---|
| Bandeja de entrada | Leyes, decretos, indultos, contratos y cartas. Arrastra el **sello** para decidir. Usa la **lupa (L)** para leer la letra pequeña: esconde trampas y corrupción. |
| Puerta | Tus ministros llaman a la puerta con dilemas urgentes (algunos con cuenta atrás). Sin visitas, convoca al Consejo de Ministros: informe, rasgos de cada ministro y **ceses y fichajes**. |
| Teléfono | Llamadas de líderes mundiales y sindicatos. Sin llamada entrante, abre tu agenda para **negociar**. |
| Teléfono rojo | Crisis: abre el **Gabinete de Crisis** (despliegue de unidades en tiempo real sobre el mapa). |
| Ordenador (SIGEP) | Datos, grupos sociales, **agenda legislativa** (presentar leyes), Congreso (reunirse con los partidos), agenda y gabinete. |
| Globo | Mapa diplomático: tratados, visitas de Estado, ayudas, sanciones. |
| Micrófono | Discurso a la nación (minijuego de ritmo con el teleprompter). En campaña abre el **mapa de campaña por regiones**. |
| Mascota | Si has comprado una en la tienda (gato, perro, loro o pez), haz clic para bajar el estrés. |
| Carpeta de cuero | Presupuestos Generales: gasto por partidas e impuestos. |
| Periódico, TV, calendario, reloj, café | Noticias, encuestas, agenda... y un café para el estrés. |
| Ventana | Refleja el estado del país: manifestaciones, disturbios, fuegos artificiales, clima. |

## Minijuegos

- **Mesa de firmas**: sellos físicos, lupa de revelado, expedientes de presos y concursos públicos.
- **Negociación**: arrastra tu oferta sobre una barra de colores. Verde: la aceptarán; ámbar: su
  límite está en esa franja; rojo: la rechazarán. Tienes 3 intentos y 3 comodines de un solo uso
  (halagar, presionar, ofrecer algo a cambio). Si no quieres arriesgar, acepta su propuesta.
- **Cumbres internacionales**: la misma negociación, pero con tres líderes a la vez. El acuerdo
  solo se firma si convence a todos (clima, fronteras, energía y libre comercio).
- **Sesión de control**: cada mes o dos, cara a cara con el líder de la oposición en el Congreso.
  5 preguntas, réplica contrarreloj y combos de aciertos.
- **Gabinete de Crisis**: incendios, pateras, huelgas, pandemia, terrorismo, apagones, golpe de Estado, guerra...
- **Congreso**: hemiciclo de 350 escaños, negociación de apoyos y votación escaño a escaño.
- **Rueda de prensa / entrevista**, **discurso** con teleprompter, **debate electoral** cara a cara.
- **Campaña por regiones**: en los últimos 60 días repartes actos (mitin, visita, anuncio de
  inversión, spot de TV) por las 8 regiones del mapa. Cada región suma a su resultado electoral.
- **Noche electoral** con escrutinio región a región.

## Tu Gobierno

Cada ministro tiene rasgos (Negociador, Austero, Tecnócrata, Veterano, Polémico, Derrochador...)
que cambian la partida: más dinero cada mes, más tiempo en la sesión de control, unidades extra
en las crisis, etc. Puedes cesar a un ministro (cuesta capital político y estabilidad) y elegir
a su sustituto entre tres candidatos.

## Tienda del Palacio

- Ganas **Laureles** jugando: leyes aprobadas, crisis bien resueltas, acuerdos, debates, cumbres,
  logros y una recompensa al final de cada legislatura.
- El escaparate cambia **cada día**, con un artículo destacado rebajado un 30 %.
- Personaliza: bandera nacional, estilo del despacho, madera del escritorio, teléfono rojo,
  globo, lámpara, traje, corbata, accesorios (pin, banda, medalla), tinta de los sellos y mascota.
- **Lingotes** (moneda premium): ahora mismo funcionan en **modo de prueba**, sin cobros reales.
  `scripts/autoload/payments.gd` explica cómo conectar Steam o Stripe cuando se publique el juego
  (los cobros reales deben validarse siempre en un servidor, nunca solo en el cliente).
- 18 logros con recompensa. El perfil se guarda aparte de la partida (`user://perfil.json`).

## Consejos

- Si te limitas a esperar, el **desgaste del poder** te hundirá. Aprueba leyes, cuida a tus socios
  (relación ≥ 60 en el Congreso) y habla al país.
- Vigila la **deuda** (quiebra al 155 %), la **estabilidad** (moción de censura) y la moral de las
  **Fuerzas Armadas** (golpe de Estado).
- La partida se guarda automáticamente cada mes.

## Archivos del proyecto

- `scripts/autoload/` — estado del juego, simulación, datos, audio, interfaz, perfil del jugador y pagos.
- `scripts/data/` — eventos, países, leyes, crisis, preguntas de prensa, discursos y catálogo de la tienda.
- `scripts/screens/` — menú, nueva partida, tienda y pantalla final.
- `scripts/office/` — el despacho (arte vectorial generado por código, ventana, TV, HUD).
- `scripts/overlays/` — cada minijuego y panel.
- `tools/gen_audio.gd` y `tools/gen_maps.gd` — generan la música, los efectos y los mapas.

Para crear un ejecutable: en Godot, *Proyecto → Exportar → Añadir → Windows Desktop*
(la primera vez te pedirá descargar las plantillas de exportación).

## Créditos y licencias

- Código, arte vectorial, música y efectos de sonido: generados por código para este proyecto.
- Tipografías de Google Fonts: Playfair Display, Inter, Oswald, Caveat, UnifrakturMaguntia,
  Share Tech Mono y Mrs Saint Delafield (SIL Open Font License) y Special Elite (Apache 2.0).
  Sus licencias están en `fonts/licencias/`.
- Países, partidos y personajes son ficticios.
