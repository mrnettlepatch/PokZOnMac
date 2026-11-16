#===============================================================================
# Adaptación a macOS (mkxp-z)
#===============================================================================
if !System.is_windows?

# Capturas de pantalla sin rubyscreen.dll (se guardan como PNG)
def pbScreenCapture
  capturefile=nil
  5000.times {|i|
     filename=RTP.getSaveFileName(sprintf("capture%03d.png",i))
     if !safeExists?(filename)
       capturefile=filename
       break
     end
  }
  return if !capturefile
  begin
    bmp=Graphics.snap_to_bitmap
    bmp.to_file(capturefile)
    bmp.dispose
    pbSEPlay("expfull") if FileTest.audio_exist?("Audio/SE/expfull")
  rescue
  end
end

# Texto: LetrasBien ajusta el texto para el mkxp de Windows (y+4 con un
# recuadro de la altura justa). En mkxp-z eso recorta la parte baja de las
# letras. Se amplía el recuadro por arriba y por abajo (mismo centro).
if $MKXP && Bitmap.method_defined?(:mkxp_draw_text)
  class Bitmap
    def draw_text(*args)
      if args[0].is_a?(Rect)
        r = args[0]
        x, y, width, height, text, align = r.x, r.y, r.width, r.height, args[1], (args[2] || 0)
      else
        x, y, width, height, text, align = args
        align ||= 0
      end
      text = text.to_s
      h = text_size(text).height
      pad = 8
      mkxp_draw_text(x, y + 4 - pad, width, h + pad * 2, text, align)
    end
  end
end

# Escribir con el teclado (nombres, apodos...): en mkxp-z Input.gets solo
# recibe letras si la entrada de texto está activada.
if Input.respond_to?(:text_input=)
  class PokemonEntryScene
    alias pokemonz_pbEntry1 pbEntry1
    def pbEntry1
      Input.text_input = true
      pokemonz_pbEntry1
    ensure
      Input.text_input = false
    end
  end
  class << Kernel
    alias pokemonz_pbFreeText pbFreeText
    def pbFreeText(*args, &block)
      Input.text_input = true
      pokemonz_pbFreeText(*args, &block)
    ensure
      Input.text_input = false
    end
  end
end

end
