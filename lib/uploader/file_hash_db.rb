module Uploader
  class FileHashDB
    PART_PREFIX = 'sums.part'

    def initialize(conf)
      @db_dir = conf.db_dir
      @logger = conf.logger
      Dir.mkdir @db_dir unless File.directory? @db_dir
      parts = Dir.glob(@db_dir + '/sums.part.*').length
      @logger.info "initialized db with #{parts} partitions"
    end

    def prefix(sum)
      raise "sum is expected to be hex digest string" unless sum.is_a? String
      raise "hexdigest string is expected to be longer than 16" unless sum.length > 16
      sum[0..1]
    end

    def save(sum)
      part = "#{@db_dir}/#{PART_PREFIX}.#{prefix(sum)}"
      lines = [ "#{sum}\n" ]
      lines << File.readlines(part) if File.exists?(part)
      File.write(part, lines.sort.join)
    end

    def sum_exists?(sum)
      part = "#{@db_dir}/#{PART_PREFIX}.#{prefix(sum)}"
      return false unless File.exists? part
      `grep -qm1 '^#{sum}$' #{part}`
      return $?.exitstatus.zero?
    end
  end
end