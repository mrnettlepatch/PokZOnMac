#===============================================================================
# Adaptación a macOS: carpeta de partidas
# ~/Library/Application Support/PokemonZ/PokemonZ
#===============================================================================
if !System.is_windows?
module RTP
  def self.getSaveFolder
    if !@@folder || @@folder=="."
      @@folder = pokemonz_save_dir
      pokemonz_migrate_saves
    end
    return @@folder
  end
end
end

#===============================================================================
# Adaptación a macOS: resolución
# El juego funciona a 512x384 (DEFAULTSCREENWIDTH/HEIGHT). La ventana la escala
# mkxp-z (se puede redimensionar y poner a pantalla completa con Option+Enter).
#===============================================================================
if !System.is_windows?
  def pbSetResizeFactor(factor=1,norecalc=false)
    $ResizeOffsetX=0
    $ResizeOffsetY=0
    pbSetResizeFactor2(1.0,true)
  end
end
