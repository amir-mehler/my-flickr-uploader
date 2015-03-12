module Uploader
  module Helpers

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