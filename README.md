# PokZOnMac

**Juega a Pokémon Z de forma nativa en macOS** (Apple Silicon e Intel), sin Wine, sin máquinas virtuales y sin JoiPlay.

PokZOnMac convierte la versión de Windows de **Pokémon Z v2.19** (fangame de la comunidad Pokémon Z, hecho con RPG Maker XP + Pokémon Essentials) en una app de Mac (`Pokemon Z.app`) que usa el motor libre [mkxp-z](https://github.com/mkxp-z/mkxp-z).

> Este repositorio **no contiene el juego** ni el motor. Solo contiene el script de conversión y los parches. Necesitas tu propia copia de Pokémon Z, descargada de los canales oficiales de su comunidad.

*[English summary below](#english).*

---

## Requisitos

- macOS 11 o posterior (probado en macOS 27, Apple Silicon M1).
- La carpeta del juego de Windows: **Pokémon Z v2.19** (la que contiene `Game.exe`, `Game.ini`, `Data`, `Graphics`, `Audio`...).
- Conexión a internet la primera vez (el script descarga mkxp-z).
- Ruby (viene de serie con macOS).

## Instalación

```bash
git clone https://github.com/mrnettlepatch/PokZOnMac.git
cd PokZOnMac
./construir.sh "/ruta/a/Pokemon Z v2.19"
```

El script crea `/Applications/Pokemon Z.app`. Ábrela con doble clic. Si macOS la bloquea la primera vez: clic derecho sobre la app → **Abrir** → **Abrir**.

Opciones:

| Opción | Uso |
|---|---|
| `./construir.sh JUEGO DESTINO` | Crea la app en otra carpeta (no uses Descargas: mkxp-z no arranca desde ahí). |
| `FORZAR=1 ./construir.sh ...` | Sustituye una app existente (la antigua va a la Papelera). |
| `MKXPZ_ZIP=/ruta.zip ./construir.sh ...` | Usa un zip de mkxp-z (`macos.universal.app`) ya descargado. |

La carpeta original del juego **no se modifica**.

## Partidas guardadas

Se guardan en `~/Library/Application Support/PokemonZ/PokemonZ`
(en Finder: *Ir → Ir a la carpeta…*).

Para continuar una partida de Windows, copia ahí tus archivos `Game*.rxdata`.

## Controles

**Teclado:** igual que en Windows. **X** abre el menú, **C/Enter/Espacio** aceptan (mantén **C** para correr), **Esc** cancela, y las **flechas** mueven.
Pantalla completa: **Option + Enter**. Reiniciar: **F12**. La ventana se puede redimensionar.

**Mando de Xbox** (se instala automáticamente):

| Botón | Función |
|---|---|
| A | Aceptar / hablar (mantener para correr) |
| B | Atrás / abrir menú |
| X | Abrir menú (como la X del teclado) |
| Start ☰ | Abrir menú |
| Y | Correr (modo alterno), Megaevolución, ordenar mochila |
| View ⧉ | Usar objeto registrado |
| LB / RB | Turbo y página anterior / página siguiente |
| LT | Atajo PokéVial (en el menú) |
| RT o L3 | Atajo PokéRider (en el menú) |
| R3 | Atajo DexNav (en el menú) |
| Cruceta o stick izquierdo | Moverse |

Para cambiar los controles, pulsa **F1** dentro del juego. Para volver al mapeado del port, borra
`~/Library/Application Support/PokemonZ/PokemonZkeybindings.mkxp1` y vuelve a ejecutar `construir.sh`.

## Qué se ha probado

Pantalla de título, introducción y creación de personaje (incluida la escritura del nombre con tildes y ñ), movimiento por el mapa, combate salvaje, combate contra entrenador (con la secuencia "VS"), todos los menús (equipo, ficha, mochila, Pokédex, tarjeta, opciones, mapa, menú de pausa y PC), guardar y cargar partida, y mando de Xbox.

## Problemas conocidos y soluciones

| Problema | Solución |
|---|---|
| La app no abre desde Descargas | Muévela a Aplicaciones (limitación de mkxp-z). |
| “No se puede abrir porque es de un desarrollador no identificado” | Clic derecho → Abrir → Abrir. |
| El juego se queda en negro tras un cierre inesperado | Ciérralo y ábrelo de nuevo; el script ya desactiva el aviso de “reabrir ventanas” de macOS. |
| Error del script de conversión “no se pudo aplicar…” | Tu versión del juego no es la 2.19; abre una *issue* indicando la versión. |

Para ver los errores del juego, ábrelo desde Terminal:

```bash
"/Applications/Pokemon Z.app/Contents/MacOS/bundle_mkxp-z"
```

## Cómo funciona

Las versiones de Windows y JoiPlay ejecutan el juego con **Ruby 1.8**, y mkxp-z para Mac usa **Ruby 3.1**. El port adapta el juego sin tocar sus gráficos ni sus datos:

- **`port/pokemonz_mac.rb`** (se carga antes que el juego):
  - emula las llamadas a Windows (`Win32API`);
  - añade la compatibilidad con Ruby 1.8: `proc` con `return`, textos UTF-8, `Thread.critical`…;
  - busca los archivos sin distinguir mayúsculas, como Windows;
  - fija la resolución a 512×384 y guarda las partidas en Application Support.
- **`port/patches.rb`**: 16 correcciones de líneas concretas de los scripts del juego.
- **`port/macos_rtp.rb`** y **`port/macos_section.rb`**: dos secciones nuevas que se insertan en `Scripts.rxdata`. Cubren la carpeta de partidas, la resolución, el texto, las capturas de pantalla y la escritura con el teclado.
- **`port/mando_xbox.mkxp1`**: el mapeado de mando, generado con `port/generar_mando.py`.

Los detalles de cada problema y su solución están en [docs/TECNICO.md](docs/TECNICO.md).

## Créditos y licencias

- **Pokémon Z**: comunidad Pokémon Z. Este proyecto no está afiliado con ellos ni con Nintendo, Game Freak o The Pokémon Company. *Pokémon* es una marca registrada de sus respectivos propietarios.
- **mkxp-z**: [mkxp-z/mkxp-z](https://github.com/mkxp-z/mkxp-z), licencia GPLv2. Se descarga durante la instalación y no se redistribuye aquí.
- **Scripts de este repositorio**: licencia MIT (ver [LICENSE](LICENSE)).

---

## English

**PokZOnMac** turns the Windows release of the fangame **Pokémon Z v2.19** (RPG Maker XP / Pokémon Essentials) into a **native macOS app**. It runs on Apple Silicon and Intel through [mkxp-z](https://github.com/mkxp-z/mkxp-z).

The game's Windows and JoiPlay builds run on Ruby 1.8, while mkxp-z for macOS ships Ruby 3.1. This repo patches the game scripts and adds a compatibility layer:

- Win32API emulation;
- Ruby 1.8 semantics (`proc`/`return`, byte indexing, string encodings);
- case-insensitive asset lookup;
- native resolution;
- keyboard text entry;
- an Xbox controller mapping.

It contains **no game files and no engine binaries**.

```bash
git clone https://github.com/mrnettlepatch/PokZOnMac.git
cd PokZOnMac
./construir.sh "/path/to/Pokemon Z v2.19"   # creates /Applications/Pokemon Z.app
```

Save files live in `~/Library/Application Support/PokemonZ/PokemonZ`. See [docs/TECNICO.md](docs/TECNICO.md) (Spanish) for the technical details.
