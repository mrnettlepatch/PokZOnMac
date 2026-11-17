# Detalles técnicos del port

## Punto de partida

Pokémon Z v2.19 es un juego de RPG Maker XP (RGSS1) hecho con Pokémon Essentials (v16 modificada).

- **Windows:** su `Game.exe` es un **mkxp-z compilado con Ruby 1.8** (`i386-mingw32`).
- **Android:** JoiPlay se configura con la opción "Usar Ruby 1.8".
- **macOS:** la única versión de mkxp-z disponible usa **Ruby 3.1**.

Así que el trabajo consiste en hacer que unos scripts escritos para Ruby 1.8 y Windows funcionen en Ruby 3.1 y macOS. El juego, además, ya usaba la API propia de mkxp-z (`$MKXP`, `Input.gets`, `Input.triggerex?(:RETURN)`…), lo que facilita mucho el port.

## Estructura de la app generada

```
Pokemon Z.app/
  Contents/MacOS/bundle_mkxp-z          motor mkxp-z (universal)
  Contents/Game/                        copia del juego (sin .exe ni .dll)
    mkxp.json                           configuración (port/mkxp.json)
    mando_xbox.mkxp1                    mapeado de mando por defecto
    Data/Scripts.rxdata                 scripts parcheados
    scripts/preload/*.rb                capas de compatibilidad
    stdlib/                             biblioteca estándar de Ruby de mkxp-z
```

mkxp-z, en macOS, usa `Contents/Game` como carpeta del juego si existe.

Orden de carga (`preloadScript` en `mkxp.json`):

1. `ruby_classic_wrap.rb`, `mkxp_wrap.rb` y `win32_wrap.rb`: los incluye mkxp-z.
2. `pokemonz_mac.rb`: lo añade este port.
3. `Scripts.rxdata`: los scripts del juego, con las secciones `MacOS_RTP` (tras `SpriteWindow`) y `MacOS` (antes de `Main`).

## Problemas encontrados y soluciones

### Llamadas a Windows (`Win32API`)

`win32_wrap.rb` (incluido en mkxp-z) emula el teclado y el ratón. `pokemonz_mac.rb` añade el resto de funciones que usa el juego:

- `GetPrivateProfileString`: lee de verdad `Game.ini`.
- `GetUserName`, `GetUserDefaultLangID` (español) y `GetSystemMetrics`.
- `FindWindowEx` y `GetWindowThreadProcessId`: sin ellas, el juego lanzaría "Can't find RGSS player window".
- `MessageBox`, `SetWindowTextA` y varias funciones sin efecto.

Las llamadas desconocidas devuelven 0, como si fallaran sin más; el juego ya contempla ese caso.

Las variables de entorno `TEMP`/`TMP` apuntan a `$TMPDIR`. `system("Game")`, que el juego usa para reiniciarse al cambiar el VSync, vuelve a abrir la app con `open -n`.

### Ruby 1.8 → Ruby 3.1

Son de dos tipos: diferencias generales, resueltas en `pokemonz_mac.rb`, y líneas concretas, corregidas en `patches.rb`.

| Problema | Síntoma | Solución |
|---|---|---|
| `when 0:` | `SyntaxError` | `when 0 then` (parche) |
| `\x7f-\x9f` en una regex | `invalid multibyte escape` | escapes `\u` (parche) |
| `retry` fuera de `rescue` | `Invalid retry` | `next` (parche) |
| `proc { return x }`: en 1.8 `proc` era una lambda | `LocalJumpError: unexpected return` (objetos, movimientos de campo, eventos) | `Kernel#proc` captura `LocalJumpError` con motivo `:return` y devuelve su valor; conserva `arity` |
| `str[i]` devolvía un byte (Integer) | `comparison of String with 6 failed`, `undefined method times for "\x01"` | `getbyte` (parches en `StringInput#getc`, lectura de OGG/MP3, rutas, GIF, BOM) |
| Polyfills de 1.8 en "Map - Klein" (`String#setbyte` = `[]=`, `bytesize` = `size`) y en "LukaUtilities" | `no implicit conversion of Integer into String` | se eliminan; Ruby 3 ya tiene los métodos de verdad (parche) |
| `Thread.critical` | `NoMethodError` | se define sin efecto |
| `Array#nitems`, `String#each` | `NoMethodError` | se definen |
| Codificación: en 1.8 los textos de los `.rxdata`/`.dat` eran bytes | acentos rotos o `Encoding::CompatibilityError` | `Marshal.load` y `load_data` marcan como UTF-8 las cadenas binarias que son UTF-8 válido |
| `Kernel.respond_to?("pbSetResizeFactor")` era `true` en 1.8 | el juego anulaba `Graphics.snap_to_bitmap` (devolvía `nil`); fallaba la transición de combate contra entrenadores | `respond_to?(..., true)` (parche) |
| `SDLError` no es `StandardError` | un `rescue` simple no capturaba un fallo al cargar una imagen | `Bitmap#initialize` lo convierte en `Errno::ENOENT` |

### Ruby 3.2 y posteriores

Para que la capa funcione también con versiones más nuevas de Ruby (por ejemplo, el núcleo web de mkxp-z, que usa Ruby 3.3):

- **Métodos eliminados en Ruby 3.2:** `File.exists?`, `FileTest.exists?`, `Dir.exists?` y `Object#=~`. Se definen siempre, igual que los de `ruby_classic_wrap.rb` (`Object#id`, `#type`, `Hash#index`) y los de Ruby 1.8 (`Array#nitems`, `String#each`, `Thread.critical`). No se comprueba antes si existen, porque en algunos builds `method_defined?` da "existe" para métodos marcados como no implementados.
- **`pokemonz_mac.rb` es idempotente:** si un motor lo carga dos veces, la segunda carga no hace nada.
- **`Marshal.load`:** sin función propia se llama con un solo argumento. mkxp-z ya marca los textos como UTF-8, y el `Marshal.load` de dos argumentos del núcleo web tiene un fallo.
- **Carpeta temporal:** `TEMP` apunta a la primera carpeta que exista de verdad.
- **Núcleo libretro:** se detecta con `System.platform == "libretro"`. En ese caso se usa el `pathCache` del motor en lugar del índice de rutas en Ruby, que sin JIT es demasiado lento.

### Detalles de mkxp-z en macOS

- **Mayúsculas en las rutas.** PhysFS las distingue (`overworldshadow.png` frente a `.PNG`), y la opción `pathCache`, que lo emula, hace que esta versión de mkxp-z se cuelgue con este juego (fallo de segmento en `PHYSFS_enumerate`). La solución es `pathCache: false` más un índice propio en Ruby (`PokemonZPaths`) que corrige la ruta en `Bitmap.new`, `Audio.*_play` y `load_data`.
- **Resolución.** RGSS1 arranca a 640×480 y el juego está hecho para 512×384. Se llama a `Graphics.resize_screen(512, 384)` tras el primer fotograma. En la sección `MacOS_RTP`, `pbSetResizeFactor` deja de manipular la ventana con Win32; el escalado lo hace mkxp-z, con la ventana redimensionable a 1024×768.
- **Texto cortado.** El script "LetrasBien" dibuja el texto con un recuadro de la altura justa, pensado para el mkxp de Windows. En mkxp-z eso recorta la parte baja de las letras. Se amplía el recuadro 8 px arriba y abajo, manteniendo el mismo centro.
- **Escribir con el teclado.** En mkxp-z, `Input.gets` solo recibe texto si `Input.text_input = true`, y el juego no lo activaba. Ahora se activa en `PokemonEntryScene#pbEntry1` y `Kernel.pbFreeText`.
- **Controles.** mkxp-z lee los controles de `customDataPath + "keybindings.mkxp1"`, y en macOS esa ruta no termina en `/`. El archivo queda como `~/Library/Application Support/PokemonZ/PokemonZkeybindings.mkxp1`. El formato es la versión 3: una cabecera `<III` (versión, rgss, número de entradas) y entradas `<iiii` (tipo, dato, dirección del eje, botón).
- **Descargas.** mkxp-z no arranca desde `~/Downloads`.
- **Aviso de "reabrir ventanas".** Si la app se cierra de golpe, macOS muestra un diálogo modal al reabrirla que bloquea el motor. Se desactiva con `NSQuitAlwaysKeepsWindows = false`.

### Partidas

Se guardan en `System.data_directory` (`~/Library/Application Support/PokemonZ/PokemonZ`), en lugar de dentro de la app. Si hay archivos `Game*.rxdata` en la carpeta del juego, se copian ahí la primera vez.

## Mapeado de mando (`generar_mando.py`)

mkxp-z asigna por defecto: A→C, B→B, **X→A**, Y→X, L3→Y, R3→Z, LB→L y RB→R.
Para Pokémon Z eso deja el menú (botón lógico B) solo en la B del mando, mientras que la X del mando sirve para correr. Es confuso, porque en el teclado el menú está en la X.

El mapeado del port pone el menú también en X y Start, y asigna el resto de funciones del juego:

- Y → A (correr, Megaevolución);
- View → F5 (objeto registrado);
- LT → X (PokéVial);
- RT → Y (PokéRider);
- R3 → Z (DexNav).

Para cambiarlo, edita `port/generar_mando.py` y ejecuta `python3 port/generar_mando.py port/mando_xbox.mkxp1`.

## Cómo se probó

Se añadió un módulo de pruebas temporal que simulaba teclas, escribía texto, lanzaba scripts dentro del juego y guardaba capturas con la función original `Graphics.snap_to_bitmap`. Con él se probaron:

- título e introducción;
- escritura del nombre ("Íñigo", recibido en UTF-8);
- movimiento por el mapa;
- combate salvaje y contra entrenador;
- todos los menús;
- guardar, y leer la partida guardada (codificación UTF-8 correcta).

El mando de Xbox se comprobó registrando las pulsaciones reales de un mando conectado. No se incluye en el repositorio.

## Adaptar otra versión del juego

`patch_scripts.rb` se detiene con un mensaje claro si alguna corrección no encaja. En ese caso:

1. Extrae los scripts para buscar el código equivalente:

   ```ruby
   ruby -rzlib -e 'Marshal.load(File.binread("Data/Scripts.rxdata")).each_with_index{|(i,n,c),k| File.binwrite(format("%03d_%s.rb",k,n.gsub(/\W/,"_")), Zlib::Inflate.inflate(c))}'
   ```

2. Ajusta `port/patches.rb`.
3. Busca `return` dentro de `proc` y comparaciones de bytes como `str[i]==0x..`: son los patrones de Ruby 1.8 más habituales.
