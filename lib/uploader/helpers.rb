module Uploader
  module Helpers

    # return english strings (as much as possible)
    def translate(str)
      begin
        # encode utf-8 and prevent bash injection
        utf = str.force_encoding("UTF-8").tr('";$&`|()','')
        unless utf.ascii_only?
          `t en '#{utf}' | sed 's/^Translation: //;s/ /_/g'`.chop.force_encoding("UTF-8")
        else
          utf
        end
      rescue => e
        raise "Failed to translate #{str} got (#{e.class}) #{e.message}. #{e.backtrace.join("\n")}"
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