require 'digest'

module Uploader
  class DiskCrawler

    def initialize(conf, cache, flickr)
      @dirs = conf.work_dirs["work_dirs"]
      @cache = cache
      @logger = conf.logger
      @flickr = flickr
    end

    def is_picture?(file)
      m = file.match(/\w+\.(?<ext>\w{3}\w?)$/)
      return m.nil? ? false : IMAGE_EXTENSIONS.include?(m["ext"].downcase)
    end

    def upload(path, sum)
      begin
        path_tags = (path.split('/')[0..-2] - @base_dir.split('/')).join(' ')
        args = {
          title: File.basename(path),
          tags: path_tags,
          is_public: 0,
          is_friend: 0,
          is_family: 1,
          safety_level: 2,
          hidden: 2,
          description: ''
        }
        flickr.upload_photo path, args
        @cache.save sum
        @logger.info "[UPLOADED] #{path}"
      rescue => e
        @logger.error "[FAILED] #{path}. #{e.message}. #{e.backtrace}"
      end
    end

    def run!
      @dirs.each do |d|
        run_on_dir(d)
      end
    end

    def run_on_dir(dir)
      Dir.glob(dir + "/*").each do |entry|
        if File.directory? entry
          if File.basename(entry).match(/^\$/)
            @logger.info "[skip] #{entry}"
            next
          end
          @logger.info "[dir] #{entry}"
          go(entry)
        elsif File.file?(entry) && is_picture?(entry)
          begin
            hexmd5sum = Digest::MD5.file(entry).hexdigest
            if @cache.sum_exists?(hexmd5sum)
              @logger.info "[old] #{entry}"
            else
              upload(entry, hexmd5sum)
            end
          rescue => e
            @logger.error "Failed processing file #{entry}. #{e.message}. #{e.backtrace}"
          end
        else
          @logger.info "[not/img] #{entry}"
        end
      end
    end

  end
end