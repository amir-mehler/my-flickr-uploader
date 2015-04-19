module Uploader
  module Helpers

    # return english strings (as much as possible)
    def translate(str)
      # Find non english/ascii strings:
      if str.force_encoding("UTF-8").ascii_only?
        str
      else # injection?
        clean = remove_bash_special_chars(str)
        `t en #{clean}`
      end
    end

    def remove_bash_special_chars(str)
      str.tr('";$`|( ','')
    end

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