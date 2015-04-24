module Uploader
  module Helpers

    # return english strings (as much as possible)
    def translate(str)
      begin
        clean = str.tr('";$&`|()','') # clean special chars
        eng = clean.ascii_only? ? clean : `t en '#{clean}' | sed 's/^Translation: //;s/ /_/g'`.chop # translate non english
        # eng.encode('UTF-8', 'ASCII-8BIT', invalid: :replace, undef: :replace, replace: '') # really force encoding
      rescue => e
        raise "Failed to translate #{str} got (#{e.class}) #{e.message}. #{e.backtrace.join("\n")}"
      end
    end

#    def remove_bash_special_chars(str)
#      str.tr('";$`|( ','')
#    end

  # $ `t en HE-STR` # => "Translation: EN-STR"

  # CountDown. Create it with N and ask it "zero?" N times for a 'true'
  class CountDown
    def initialize(n)
      set(n)
    end
    def zero?() (@n -= 1).zero? ; end
    def get()    @n             ; end
    def set(n)   @n = n         ; end
  end
end
end