# Correcciones puntuales a los scripts de Pokémon Z (Data/Scripts.rxdata).
#
# El juego se ejecuta en Windows y JoiPlay con Ruby 1.8; mkxp-z para macOS usa
# Ruby 3.1. Cada entrada es: [sección, texto/regex original, reemplazo, descripción].
# Las diferencias de Ruby 1.8 que se pueden resolver de forma general están en
# pokemonz_mac.rb; aquí solo van las que exigen tocar una línea concreta.
module PokZOnMac
  PATCHES = [
    # --- Sintaxis que ya no existe en Ruby 3 -------------------------------
    ["AudioUtilities", /^(\s*when\s+\d+):/n, '\1 then',
     'sintaxis "when x:" de Ruby 1.8'],
    ["PSystem_Utilities NUEVO", '\x00-\x1f\x7f-\x9f]*"/', '\u0000-\u001f\u007f-\u009f]*"/',
     "escapes \\x no válidos en una regex UTF-8"],
    ["PScreen_Load", "retry if deleting==false", "next if deleting==false",
     "retry fuera de rescue (mismo efecto: repetir el bucle)"],

    # --- str[i] devolvía un byte (Integer) en Ruby 1.8; ahora un carácter ---
    ["AudioUtilities", "file.read(1)[0]", "file.read(1).getbyte(0)",
     "lectura de bytes (duración de OGG/MP3)"],
    ["AudioUtilities", "rstr[0]", "rstr.getbyte(0)", "lectura de bytes (cabecera MP3)"],
    ["AudioUtilities", "rstr[1]", "rstr.getbyte(1)", "lectura de bytes (cabecera MP3)"],
    ["Intl_Messages", "line[0]==0xEF && line[1]==0xBB && line[2]==0xBF",
     "line.getbyte(0)==0xEF && line.getbyte(1)==0xBB && line.getbyte(2)==0xBF",
     "detección de BOM UTF-8"],
    ["SpriteWindow", "file[file.length-1]!=0x2F", "file[-1,1]!=\"/\"",
     "comprobación de ruta terminada en /"],
    ["SpriteWindow", "filestring[0]==0x47", "filestring.getbyte(0)==0x47",
     "detección de GIF"],
    ["SpriteWindow", "    ch = @string[@pos]\r\n", "    ch = @string.getbyte(@pos)\r\n",
     "StringInput#getc devuelve un byte (datos de Pokémon, experiencia...)"],

    # --- Polyfills de Ruby 1.8 / hacks de Windows que rompen Ruby 3 ---------
    ["Map - Klein", /class String\s+alias getbyte\s+\[\]\s+alias setbyte\s+\[\]=\s+alias bytesize size\s+end/n,
     "# (macOS) polyfills de String de Ruby 1.8 eliminados",
     "quitar String#getbyte/setbyte/bytesize falsos"],
    ["Map - Klein", "def self.snap_to_bitmap", "def self.klein_snap_to_bitmap_win32",
     "no sustituir la captura de pantalla nativa por la de Windows (GDI)"],
    ["Map - Klein", "  def _dump(level)", "  def klein_dump_win32(level)",
     "desactivar Bitmap#_dump basado en memoria de Windows"],
    ["Map - Klein", "  def self._load(dump)", "  def self.klein_load_win32(dump)",
     "desactivar Bitmap._load basado en memoria de Windows"],
    ["LukaUtilities", /def bytesize\s+return self\.size\s+end/n, "# (macOS) bytesize nativo",
     "quitar String#bytesize = size (en Ruby 3 no son lo mismo)"],

    # --- Diferencias de comportamiento ---------------------------------------
    ["PSystem_System", 'if !Kernel.respond_to?("pbSetResizeFactor")',
     'if !Kernel.respond_to?("pbSetResizeFactor", true)',
     "no anular Graphics.snap_to_bitmap (combates contra entrenadores, transiciones)"],
  ]
end
