require 'Daybreak'

module Uploader
  class FileHashDB

    def initialize(conf)
      @logger = conf.logger
#      path = "#{@base_dir}/db/#{conf.username}.dbk"
#      @db = Daybreak::DB.new(path)
#      conf.set_db @db
#      @logger.info "initialized db: #{conf.username}.dbk"
#      @db
    end

#    def close() @db.close; end

    def prefix(sum)
      raise "sum is expected to be hex digest string" unless sum.is_a? String
      raise "hexdigest string is expected to be longer than 16" unless sum.length > 16
      sum[0..1]
    end

    # def save(sum)
    #   part = "#{@db_dir}/#{PART_PREFIX}.#{prefix(sum)}"
    #   lines = [ "#{sum}\n" ]
    #   lines << File.readlines(part) if File.exists?(part)
    #   File.write(part, lines.sort.join)
    # end

    # def sum_exists?(sum)
    #   part = "#{@db_dir}/#{PART_PREFIX}.#{prefix(sum)}"
    #   return false unless File.exists? part
    #   `grep -qm1 '^#{sum}$' #{part}`
    #   return $?.exitstatus.zero?
    # end
  end
end