# patch_scripts.rb — aplica el port de macOS a Data/Scripts.rxdata de Pokémon Z.
#
# Uso: ruby patch_scripts.rb ORIGINAL.rxdata SALIDA.rxdata
#
# - Aplica las correcciones de patches.rb (Ruby 1.8 -> Ruby 3) a secciones concretas.
# - Inserta la sección "MacOS_RTP" (macos_rtp.rb) justo después de "SpriteWindow".
# - Inserta la sección "MacOS" (macos_section.rb) justo antes de "Main".
#
# Funciona con el Ruby de serie de macOS (2.6) o cualquier Ruby >= 2.6.
require "zlib"

abort "Uso: ruby #{File.basename(__FILE__)} ORIGINAL.rxdata SALIDA.rxdata" unless ARGV.size == 2
orig, out = ARGV
here = File.dirname(File.expand_path(__FILE__))

load File.join(here, "patches.rb") # define PokZOnMac::PATCHES

scripts = Marshal.load(File.binread(orig))
abort "Error: #{orig} no parece un Scripts.rxdata válido" unless scripts.is_a?(Array) && scripts.all? { |s| s.is_a?(Array) && s.size == 3 }
if scripts.any? { |s| s[1].b == "MacOS".b || s[1].b == "MacOS_RTP".b }
  abort "Error: este Scripts.rxdata ya tiene el port aplicado. Usa el original del juego."
end

def find_section(scripts, name)
  scripts.find { |s| s[1].b == name.b } or abort("Error: no existe la sección '#{name}'. ¿Es otra versión del juego?")
end

PokZOnMac::PATCHES.each do |section, old, new, desc|
  entry = find_section(scripts, section)
  code = Zlib::Inflate.inflate(entry[2]).b
  if old.is_a?(Regexp)
    abort("Error: no se pudo aplicar '#{desc}' en '#{section}'. ¿Es otra versión del juego?") unless code =~ old
    code = code.gsub(old, new.b)
  else
    abort("Error: no se pudo aplicar '#{desc}' en '#{section}'. ¿Es otra versión del juego?") unless code.include?(old.b)
    code = code.gsub(old.b) { new.b }
  end
  entry[2] = Zlib::Deflate.deflate(code)
  puts "  ✓ #{section}: #{desc}"
end

sw = scripts.index { |s| s[1].b == "SpriteWindow".b } or abort("Error: no existe la sección 'SpriteWindow'")
scripts.insert(sw + 1, [90000001, "MacOS_RTP".b, Zlib::Deflate.deflate(File.binread(File.join(here, "macos_rtp.rb")))])
main = scripts.index { |s| s[1].b == "Main".b } or abort("Error: no existe la sección 'Main'")
scripts.insert(main, [90000002, "MacOS".b, Zlib::Deflate.deflate(File.binread(File.join(here, "macos_section.rb")))])

File.binwrite(out, Marshal.dump(scripts))
puts "  ✓ #{PokZOnMac::PATCHES.size} correcciones + 2 secciones nuevas (#{scripts.size} secciones en total)"
