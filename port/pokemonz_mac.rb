# pokemonz_mac.rb
# (Protección: algunos motores, como el núcleo web de mkxp-z, cargan los
#  scripts de mkxp.json dos veces; la segunda carga no debe hacer nada.)
unless $pokemonz_mac_loaded
$pokemonz_mac_loaded = true

# Adaptaciones de Pokémon Z (Essentials + mkxp-z) para macOS.
# Se carga después de win32_wrap.rb, que ya emula teclado/ratón de Win32API.
# Aquí se añaden las funciones de Windows que usan los scripts del juego
# y que no tienen equivalente en macOS.

$MKXP = true

# Variables de entorno de Windows que usan los scripts
ENV["TEMP"] ||= [ENV["TMPDIR"], "/tmp", (System.data_directory rescue nil), Dir.pwd].compact.
  map { |d| d.to_s.sub(/\/+\z/, "") }.find { |d| !d.empty? && File.directory?(d) }
ENV["TMP"] ||= ENV["TEMP"]

# Resolución nativa del juego (DEFAULTSCREENWIDTH x DEFAULTSCREENHEIGHT).
# Se aplica tras el primer fotograma (antes bloquea el motor).
module Graphics
  class << self
    alias_method :pokemonz_res_update, :update
    def update(*args)
      pokemonz_res_update(*args)
      unless $pokemonz_resized
        $pokemonz_resized = true
        begin
          Graphics.resize_screen(512, 384)
        rescue => e
          System.puts("resize_screen: #{e.message}") rescue nil
        end
      end
    end
  end
end

# Carpeta del juego (Contents/Game) y bundle .app que lo contiene.
POKEMONZ_GAME_DIR = Dir.pwd
# Núcleo web (libretro): sin JIT, ya trae pathCache y conversión UTF-8
POKEMONZ_WEB = ((System.platform rescue "").to_s.downcase == "libretro")
POKEMONZ_APP_BUNDLE = File.expand_path("../..", POKEMONZ_GAME_DIR)

# Carpeta de partidas: ~/Library/Application Support/PokemonZ/PokemonZ
def pokemonz_save_dir
  return $pokemonz_save_dir if $pokemonz_save_dir
  dir = nil
  begin
    dir = System.data_directory
  rescue
    dir = nil
  end
  if !dir || dir.empty?
    dir = File.join(ENV["HOME"].to_s, "Library", "Application Support", "PokemonZ")
  end
  dir = dir.sub(/[\/\\]+\z/, "")
  path = ""
  dir.split("/").each do |part|
    next if part.empty?
    path += "/" + part
    (Dir.mkdir(path) rescue nil) unless File.directory?(path)
  end
  $pokemonz_save_dir = dir
  return dir
end

# Copia las partidas que hubiera en la carpeta del juego (versión de Windows
# copiada a mano) a la carpeta de partidas de macOS, sin sobrescribir nada.
def pokemonz_migrate_saves
  dest = pokemonz_save_dir
  Dir.glob(File.join(POKEMONZ_GAME_DIR, "Game*.rxdata")).each do |f|
    target = File.join(dest, File.basename(f))
    next if File.exist?(target)
    File.binwrite(target, File.binread(f)) rescue nil
  end
rescue
end

# Reabre el juego (lo usa el menú de opciones al cambiar VSync, etc.)
def pokemonz_relaunch
  begin
    pid = Process.spawn("/usr/bin/open", "-n", POKEMONZ_APP_BUNDLE)
    Process.detach(pid)
  rescue
  end
end

module Kernel
  alias_method :pokemonz_orig_system, :system
  def system(*args)
    cmd = args.join(" ").strip
    # Los scripts reinician el juego con system("Game") como en Windows.
    if cmd =~ /\A(\.\/)?Game(\.exe)?(\s+debug)?\z/i
      pokemonz_relaunch
      return true
    end
    pokemonz_orig_system(*args)
  end
  module_function :system
end

def pokemonz_write_cstr(buf, str, maxlen = nil)
  return 0 unless buf.is_a?(String)
  bytes = str.to_s.b
  maxlen ||= buf.bytesize
  n = [bytes.bytesize, [maxlen - 1, 0].max, [buf.bytesize - 1, 0].max].min
  n.times { |i| buf.setbyte(i, bytes.getbyte(i)) }
  buf.setbyte(n, 0) if buf.bytesize > n
  return n
end

def pokemonz_read_ini(file, section, key)
  path = file.to_s.gsub("\\", "/")
  path = File.join(POKEMONZ_GAME_DIR, File.basename(path)) unless File.exist?(path)
  return nil unless File.exist?(path)
  current = nil
  File.read(path, mode: "rb").force_encoding("UTF-8").scrub("?").each_line do |line|
    line = line.strip
    if line =~ /\A\[(.+)\]\z/
      current = $1.strip
    elsif current && current.casecmp?(section.to_s) && line =~ /\A([^=]+)=(.*)\z/
      return $2.strip if $1.strip.casecmp?(key.to_s)
    end
  end
  nil
rescue
  nil
end

module Win32API_Impl
  module Kernel32
    class GetPrivateProfileString
      def call(args)
        section, key, default, buf, size, file = args
        val = pokemonz_read_ini(file, section, key) || default.to_s
        return pokemonz_write_cstr(buf, val, size.to_i)
      end
    end
    class WriteProfileString;  def call(args); 1; end; end
    class GetCurrentProcess;   def call(args); 1; end; end
    class SetPriorityClass;    def call(args); 1; end; end
    class GetCurrentThreadId;  def call(args); 1; end; end
    class GetLastError;        def call(args); 0; end; end
    class GetUserDefaultLangID; def call(args); 0x0C0A; end; end # Español
    class GetUserGeoID;        def call(args); 217; end; end     # España
    class GetSystemPowerStatus; def call(args); 0; end; end
    class RtlMoveMemory;       def call(args); 0; end; end
    class LoadLibrary;         def call(args); 0; end; end
    class FreeLibrary;         def call(args); 0; end; end
  end

  module User32
    class FindWindowEx
      def call(args)
        return args[1].to_i == 0 ? 42 : 0
      end
    end
    class FindWindow
      def call(args); 42; end
    end
    class GetWindowThreadProcessId
      def call(args); 1; end
    end
    class GetForegroundWindow
      def call(args); 42; end
    end
    class GetSystemMetrics
      def call(args)
        idx = args[0].to_i
        begin
          w, h = Graphics.display_width, Graphics.display_height
        rescue
          w, h = 1920, 1080
        end
        return w if idx == 0
        return h if idx == 1
        0
      end
    end
    class GetWindowRect
      def call(args)
        rect = [0, 0, Graphics.width, Graphics.height] rescue [0, 0, 640, 480]
        memcpy_string(args[1], rect.pack("l4")) if args[1].is_a?(String)
        1
      end
    end
    class SetWindowTextA
      def call(args)
        Graphics.title = args[1].to_s rescue nil
        1
      end
    end
    class MessageBox
      def call(args)
        msg = args[1].to_s
        title = args[2].to_s
        System.puts("[#{title}] #{msg}") rescue nil
        1
      end
    end
    class SetWindowPos;  def call(args); 1; end; end
    class SetWindowLong; def call(args); 0; end; end
    class ShowWindow;    def call(args); 1; end; end
    class SetCapture;    def call(args); 0; end; end
    class ReleaseCapture; def call(args); 1; end; end
    class PostMessage;   def call(args); 1; end; end
    class SendMessage;   def call(args); 0; end; end
    class PeekMessage;   def call(args); 0; end; end
    class RegisterHotKey; def call(args); 0; end; end
  end

  module Advapi32
    class GetUserName
      def call(args)
        name = ENV["USER"].to_s
        name = "" if name == "root"
        return 0 if name.empty?
        pokemonz_write_cstr(args[0], name)
        1
      end
    end
  end
end

#===============================================================================
# Compatibilidad Ruby 1.8 -> Ruby 3 (el juego se escribió para Ruby 1.8)
#===============================================================================
# Ninguno de estos métodos existe en Ruby 3.x, así que se definen siempre.
# (No se comprueba antes: en el Ruby del núcleo web, method_defined? e
#  instance_method dan "existe" para métodos marcados como no implementados.)
def pokemonz_define(mod, name, &body)
  mod.send(:define_method, name, &body)
end

pokemonz_define(Thread.singleton_class, :critical) { false }
pokemonz_define(Thread.singleton_class, :critical=) { |v| v }

# Métodos eliminados en Ruby 3.2 (el núcleo web usa Ruby 3.3)
pokemonz_define(File.singleton_class, :exists?) { |f| File.exist?(f) }
pokemonz_define(FileTest.singleton_class, :exists?) { |f| FileTest.exist?(f) }
pokemonz_define(Dir.singleton_class, :exists?) { |f| Dir.exist?(f) }
pokemonz_define(Object, :=~) { |_other| nil }

# Equivalentes de ruby_classic_wrap.rb (Object#id, #type, Hash#index...)
pokemonz_define(Object, :id) { object_id }
pokemonz_define(Object, :type) { self.class }
pokemonz_define(Hash, :index) { |v| key(v) }
NilClass.send(:define_method, :id) { 4 }
TrueClass.send(:define_method, :id) { 2 }
Object.const_set(:TRUE, true) unless Object.const_defined?(:TRUE)
Object.const_set(:FALSE, false) unless Object.const_defined?(:FALSE)
Object.const_set(:NIL, nil) unless Object.const_defined?(:NIL)

pokemonz_define(Array, :nitems) { count { |x| !x.nil? } }
pokemonz_define(String, :each) { |*args, &block| each_line(*args, &block) }

# Ruby 1.8 no tenía codificaciones: los textos guardados en los .rxdata/.dat
# se cargan como binarios. Se marcan como UTF-8 para que acentos y eñes
# funcionen igual que en Windows.
module PokemonZEncoding
  UTF8 = Encoding::UTF_8
  BIN  = Encoding::ASCII_8BIT
  SKIP = [Table, Color, Tone, Rect, Bitmap, Font] rescue []

  def self.fix_string(s)
    return s if s.frozen? || s.encoding != BIN
    s.force_encoding(UTF8)
    s.force_encoding(BIN) unless s.valid_encoding?
    s
  end

  def self.fix(obj, seen = {})
    case obj
    when String
      fix_string(obj)
    when Symbol, Numeric, NilClass, TrueClass, FalseClass
      # nada
    else
      id = obj.__id__
      return obj if seen[id]
      seen[id] = true
      case obj
      when Array
        obj.each { |x| fix(x, seen) }
      when Hash
        obj.each { |k, v| fix(k, seen); fix(v, seen) }
      else
        return obj if SKIP.any? { |k| obj.is_a?(k) }
        obj.instance_variables.each { |iv| fix(obj.instance_variable_get(iv), seen) }
      end
    end
    obj
  end
end

module Marshal
  class << self
    alias_method :pokemonz_orig_load, :load
    # Sin proc propio se llama con un solo argumento y se corrige el resultado
    # después: el Marshal.load de 2 argumentos del núcleo web de mkxp-z usa el
    # primer argumento como proc (fallo del motor).
    def load(source, proc = nil, **kw)
      if proc.respond_to?(:call)
        fixer = lambda do |o|
          PokemonZEncoding.fix_string(o) if o.is_a?(String)
          proc.call(o)
        end
        pokemonz_orig_load(source, fixer, **kw)
      else
        pokemonz_orig_load(source, **kw) # mkxp-z ya marca los textos como UTF-8
      end
    end
    alias_method :restore, :load
  end
end

alias pokemonz_orig_load_data load_data
def load_data(filename)
  return pokemonz_orig_load_data(filename) if POKEMONZ_WEB
  PokemonZEncoding.fix(pokemonz_orig_load_data(filename))
end

# En RGSS/Ruby 1.8 un fallo al cargar una imagen lanzaba un error normal
# (StandardError) que los scripts capturan con "rescue". En mkxp-z es
# SDLError, que esos "rescue" no capturan: se convierte para mantener
# el comportamiento original.
class Bitmap
  alias_method :pokemonz_orig_initialize, :initialize
  def initialize(*args)
    pokemonz_orig_initialize(*args)
  rescue StandardError
    raise
  rescue SDLError, Exception => e
    raise if e.is_a?(SystemExit) || e.is_a?(Interrupt) || e.is_a?(NoMemoryError) ||
             (defined?(Reset) && e.is_a?(Reset)) || (defined?(Hangup) && e.is_a?(Hangup))
    raise Errno::ENOENT, e.message
  end
end

#===============================================================================
# Rutas sin distinguir mayúsculas/minúsculas (como en Windows).
# El motor (PhysFS) sí las distingue al cargar imágenes, sonidos y datos,
# y el juego pide p. ej. "overworldshadow.png" cuando el archivo es ".PNG".
#===============================================================================
module PokemonZPaths
  EXTS = ["", ".png", ".PNG", ".jpg", ".bmp", ".gif", ".ogg", ".mp3", ".wav", ".mid", ".midi", ".wma", ".rxdata"]
  @index = nil

  def self.index
    return @index if @index
    @index = {}
    Dir.glob("**/*", base: POKEMONZ_GAME_DIR).each do |f|
      @index[f.downcase] ||= f
    end
    @index
  end

  def self.normalize(path)
    p = path.to_s.tr("\\", "/").sub(/\A\.\//, "")
    p = p.sub(POKEMONZ_GAME_DIR + "/", "") if p.start_with?(POKEMONZ_GAME_DIR + "/")
    p
  end

  # Devuelve la ruta con las mayúsculas reales del disco, o la original.
  def self.resolve(path)
    return path if POKEMONZ_WEB # en la web se usa pathCache del motor
    return path unless path.is_a?(String) && !path.empty?
    p = normalize(path)
    return path if p.start_with?("/")
    real = index[p.downcase]
    return real if real && !File.directory?(File.join(POKEMONZ_GAME_DIR, real))
    # Sin extensión: el motor prueba extensiones; buscamos la real.
    if File.extname(p).empty?
      EXTS.each do |e|
        next if e.empty?
        r = index[(p + e).downcase]
        return r if r
      end
    end
    path
  end
end

class Bitmap
  alias_method :pokemonz_paths_initialize, :initialize
  def initialize(*args)
    args[0] = PokemonZPaths.resolve(args[0]) if args.length == 1 && args[0].is_a?(String)
    pokemonz_paths_initialize(*args)
  end
end

module Audio
  class << self
    [:bgm_play, :bgs_play, :me_play, :se_play].each do |m|
      next unless method_defined?(m)
      alias_method "pokemonz_#{m}", m
      define_method(m) do |name, *rest|
        send("pokemonz_#{m}", PokemonZPaths.resolve(name), *rest)
      end
    end
  end
end

alias pokemonz_paths_load_data load_data
def load_data(filename)
  pokemonz_paths_load_data(PokemonZPaths.resolve(filename))
end

# Ruby 1.8: proc{} se comportaba como lambda, así que un "return" dentro
# devolvía un valor desde el bloque. En Ruby 3 da LocalJumpError cuando el
# proc se definió en el nivel superior de un script (manejadores de objetos,
# movimientos, eventos...). Se captura y se devuelve el valor, como en 1.8.
module Kernel
  def proc(&blk)
    raise ArgumentError, "tried to create Proc object without a block" unless blk
    return blk if blk.lambda?
    wrapper = Proc.new do |*args, &b|
      begin
        blk.call(*args, &b)
      rescue LocalJumpError => e
        raise unless e.reason == :return
        e.exit_value
      end
    end
    orig_arity = blk.arity
    wrapper.define_singleton_method(:arity) { orig_arity }
    wrapper
  end
  module_function :proc
end

# Mapeado de mando de Xbox: si no hay controles personalizados, se instala
# el incluido (se aplica en el siguiente arranque; se puede cambiar con F1).
begin
  # mkxp-z no añade "/" a la ruta: el archivo queda junto a la carpeta de
  # partidas, como ".../PokemonZ/PokemonZkeybindings.mkxp1"
  kb = pokemonz_save_dir + "keybindings.mkxp1"
  src = File.join(POKEMONZ_GAME_DIR, "mando_xbox.mkxp1")
  File.binwrite(kb, File.binread(src)) if !File.exist?(kb) && File.exist?(src)
rescue
end

end # unless $pokemonz_mac_loaded
