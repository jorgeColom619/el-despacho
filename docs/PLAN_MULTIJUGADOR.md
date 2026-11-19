# Plan del modo multijugador «Países rivales»

Cada jugador es presidente de un país distinto del mismo mundo. Negocian, compiten y se hacen la vida
imposible a la vez, con el mismo reloj. Los países que no lleva nadie los juega la IA.

## Decisiones tomadas

- **Modo:** países rivales (no cooperativo ni por turnos).
- **Conexión:** IP directa, sin servidor propio. El juego abre el puerto solo (UPnP). Si el router no lo
  permite, reenvío de puertos a mano o una red privada (Tailscale, ZeroTier, Radmin VPN).
- **Cada jugador, un país real y distinto**, el mismo para los dos ordenadores.
- **Todos los países jugables**, cada uno con sus ventajas: uno tiene gas, otro petróleo, otro industria...
- **Como la vida real:** cada país con su régimen político. Cada país tiene su líder; los libres los lleva la IA.
  La arquitectura sirve para varios jugadores; se prueba con dos.

## Fases

| Fase | Qué incluye | Estado |
|---|---|---|
| 1. Ficha de país e identidad | Los datos fijos de Valdoria pasan a una ficha por país. Valdoria y Norland jugables. | **Hecha** |
| 2. Recursos y mercado mundial | Gas, petróleo, alimentos, industria, tecnología y minerales con precios. Cortes de suministro, embargos, agua del río. | **Hecha** |
| 3. Regímenes | Marco común y después Kharovia, Tsaing, Qadar, Sarvenia y Aldora. | Pendiente |
| 4. Multijugador por IP directa | UPnP automático, varios jugadores (probado con dos), reloj común, IA para los libres, diplomacia entre jugadores. | Pendiente |
| 5. Contenido propio | Eventos, tramas y escenarios escritos para cada país. | Pendiente |

## Los países

La Unión Continental no es jugable: es un bloque, no un país con presidente.

| País | Perfil | Ventaja | Arma |
|---|---|---|---|
| Valdoria | Equilibrada | Turismo, agricultura, fondos de la Unión | Importa energía |
| Norland | Superpotencia | Finanzas, tecnología, ejército, deuda barata | Sanciones financieras |
| Kharovia | Exportador de gas | Gas | Cortar el suministro |
| Tsaing | Fábrica del mundo | Industria | Invertir y luego cobrar |
| Qadar | Petroestado | Petróleo y fondo soberano | Precio del crudo |
| Sarvenia | Cuartel | Ejército, río Seco | Cortar el agua |
| Aldora | Promesa pobre | Minerales para baterías, el estrecho, población joven | Cerrar el paso |

## Regímenes

| País | Régimen | Cómo se juega |
|---|---|---|
| Valdoria | Democracia parlamentaria | El juego actual: Congreso de siete partidos |
| Norland | República federal presidencial | Dos cámaras, elecciones de mitad de mandato, límite de dos mandatos, gobernadores |
| Aldora | Democracia frágil | Elecciones libres pero instituciones débiles |
| Kharovia | Autoritarismo electoral | Amañar elecciones, oligarcas, servicios de seguridad, prensa controlada |
| Tsaing | Partido único | Politburó, purgas, el crecimiento como legitimidad |
| Qadar | Emirato | Sin elecciones: familia real, clérigos, sucesión, golpe de palacio |
| Sarvenia | Junta militar | Lealtad de los generales, contragolpe, transición democrática como final |

Equivalencias comunes: el Congreso pasa a ser la cámara de cada régimen, la aprobación pasa a ser
legitimidad, las elecciones son libres, controladas o no existen, la libertad de prensa varía y cada
régimen tiene sus propios finales.

## Multijugador (fase 4)

- **Red:** ENet por IP directa. Mapeo de puerto automático con la clase `UPNP` de Godot y avisos claros
  si falla. Más adelante, WebRTC con códigos de invitación.
- **Código aislado** en `scripts/autoload/red.gd`.
- **Autoridad:** cada ordenador manda en su país. El anfitrión manda en el reloj, las relaciones entre
  países, los tratados, las crisis compartidas y los sorteos comunes. Mensajes pequeños.
- **Reloj:** abrir un panel lo frena al 25 %. Pausa total solo si los dos están en un panel o negociando
  entre ellos. El anfitrión fija la velocidad.
- **Entre jugadores:** relación bilateral, llamadas en directo con frases preparadas (y chat opcional),
  negociaciones y tratados, sanciones, aranceles, ayuda, embajadores, crisis compartidas, cumbres,
  espionaje y filtraciones, noticias del otro país.
- **Victoria:** puntuación combinada (propuesta).
- **Trampas:** sin control (es para jugar entre amigos).

## Fase 1: cómo funciona

- `scripts/data/paises_data.gd`: ficha de cada país jugable (nombre, gentilicios, capital, moneda,
  regiones, partidos, personajes, mapa, bandera, nombres) y, para Valdoria, cómo es cuando es extranjera.
- `scripts/systems/pais.gd`: al empezar o cargar una partida, cambia en todos los textos de datos lo que
  es de Valdoria por lo del país elegido (en una sola pasada y respetando palabras y hashtags), aparta
  los eventos, tramas, escenarios y cumbres que solo tienen sentido en Valdoria y pone a Valdoria en el
  mundo como país extranjero.
- Los datos de los scripts de datos son `static var` (antes `const`) para poder cambiarlos al vuelo.
- `GS.usar_pais(p)`; la partida guarda `pais`. Las partidas antiguas cargan como Valdoria.
- Textos del código con `GS.fmt` (`{pais}`, `{cap}`, `{gent}`...), `W.COUNTRY_NAME`, `W.CAPITAL` y
  `UI.money` / `UI.eur` con la moneda del país.
- Banderas: `"propia"` es la del país que se gobierna. Globos y mapas resaltan el país propio.
- Mapa de Norland generado con `tools/gen_maps.gd` (`-- --solo=norland`).
- Selector de país en la pantalla de nueva partida.

### Pruebas

```
godot --headless --path . -- --check
godot --headless --path . -- --paistest          # MUESTRA=20 imprime frases adaptadas
godot --headless --path . -- --autotest=730 --runs=4 --strategy=player --difficulty=1 --pais=norland
godot --path . -- --uitest --pais=norland
godot --path . -- --shot=newgame --pais=norland --capt=captura.png
```

## Fase 2: cómo funciona

- `scripts/data/recursos_data.gd`: seis recursos (gas, petróleo, alimentos, industria, tecnología y
  minerales), el perfil de cada país (+ exporta, − importa), su fuerza y su punto débil, el recurso que cada
  uno puede cortar y las sacudidas del mercado mundial.
- `scripts/systems/mercado.gd`: precios con índice 100 = lo normal. Cada mes vuelven poco a poco a lo
  normal, con ruido, el gas sube en invierno y a veces hay una sacudida (huracán, ola de frío, cosecha récord).
  El país que se gobierna nota los precios en:
  - el saldo mensual (`Mercado.saldo()`, dentro de `GS.monthly_balance()`),
  - el objetivo de la economía (`Mercado.economia_mod()`),
  - la inflación: el gas, el petróleo y los alimentos empujan los precios de quien los compra
    (`Mercado.inflacion_mod()`, dentro de `Gobierno.inflation_target()`).
- **Cortes de suministro:** si la relación con un proveedor baja de −25, puede cortarnos lo que le compramos.
  Kharovia corta el gas, Qadar el petróleo, Tsaing la industria, Aldora los minerales, Norland la tecnología
  y Sarvenia el agua del río Seco (solo a Valdoria, que está río abajo; sin agua se pierden cosechas).
  Ese recurso nos cuesta un 60 % más. Llega un aviso al despacho con cuatro salidas: negociar, buscar otros
  proveedores (el recargo baja al 20 %), aguantar o responder con sanciones. El corte se acaba si la
  relación sube de +10 o pasan 5-8 meses.
- **Embargo comercial:** nueva acción en el mapa del mundo. Dura un año. Hunde la relación, y si ese país era
  nuestro gran proveedor de algo, a nosotros también nos cuesta.
- **Mapa del mundo:** cada país muestra lo que exporta e importa, su fuerza y su punto débil. El botón
  «Mercado mundial» enseña los precios, lo que compramos o vendemos y su efecto en el saldo, la economía y
  la inflación.
- La partida guarda el mercado. Las partidas antiguas lo crean al cargarlas.

```
godot --headless --path . -- --paistest --mercadotest
MERCADO=corte godot --path . -- --shot=office --open=mercado
```
