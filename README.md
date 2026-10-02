# EL DESPACHO — Simulador presidencial

Eres el nuevo presidente de la República de Valdoria. Tienes una legislatura para gobernar,
sobrevivir a las crisis, negociar con el mundo y ganar la reelección. Todo ocurre desde tu despacho.

![El despacho](docs/capturas/despacho.png)

| | |
|---|---|
| ![Asesor](docs/capturas/asesor.png) | ![Negociación](docs/capturas/negociacion.png) |
| ![Gabinete de crisis](docs/capturas/crisis.png) | ![Congreso](docs/capturas/congreso.png) |
| ![Documentos](docs/capturas/documentos.png) | ![Periódico](docs/capturas/periodico.png) |

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
| Puerta | Tus ministros llaman a la puerta con dilemas urgentes (algunos con cuenta atrás). Sin visitas, convoca al Consejo de Ministros para un informe. |
| Teléfono | Llamadas de líderes mundiales y sindicatos. Sin llamada entrante, abre tu agenda para **negociar**. |
| Teléfono rojo | Crisis: abre el **Gabinete de Crisis** (despliegue de unidades en tiempo real sobre el mapa). |
| Ordenador (SIGEP) | Datos, grupos sociales, **agenda legislativa** (presentar leyes), Congreso (reunirse con los partidos), agenda y gabinete. |
| Globo | Mapa diplomático: tratados, visitas de Estado, ayudas, sanciones. |
| Micrófono | Discurso a la nación / mitin de campaña (minijuego de ritmo con el teleprompter). |
| Carpeta de cuero | Presupuestos Generales: gasto por partidas e impuestos. |
| Periódico, TV, calendario, reloj, café | Noticias, encuestas, agenda... y un café para el estrés. |
| Ventana | Refleja el estado del país: manifestaciones, disturbios, fuegos artificiales, clima. |

## Minijuegos

- **Mesa de firmas**: sellos físicos, lupa de revelado, expedientes de presos y concursos públicos.
- **Negociación**: medidor de acuerdo, ánimo y paciencia del interlocutor, 6 tácticas y contraofertas.
- **Gabinete de Crisis**: incendios, pateras, huelgas, pandemia, terrorismo, apagones, golpe de Estado, guerra...
- **Congreso**: hemiciclo de 350 escaños, negociación de apoyos y votación escaño a escaño.
- **Rueda de prensa / entrevista**, **discurso** con teleprompter, **debate electoral** cara a cara.
- **Noche electoral** con escrutinio región a región.

## Consejos

- Si te limitas a esperar, el **desgaste del poder** te hundirá. Aprueba leyes, cuida a tus socios
  (relación ≥ 60 en el Congreso) y habla al país.
- Vigila la **deuda** (quiebra al 155 %), la **estabilidad** (moción de censura) y la moral de las
  **Fuerzas Armadas** (golpe de Estado).
- La partida se guarda automáticamente cada mes.

## Archivos del proyecto

- `scripts/autoload/` — estado del juego, simulación, datos, audio e interfaz.
- `scripts/data/` — eventos, países, leyes, crisis, preguntas de prensa y discursos.
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
