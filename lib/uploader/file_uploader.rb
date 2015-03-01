module Uploader
  class FileUploader
    def self.run!(queue, cache, logger)
      while i = queue.pop
        upload(i[:path], i[:sum], cache, logger)
      end
    end

    def upload(path, sum, cache, logger)
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
        cache.save sum
        logger.info "[UPLOADED] #{path}"
      rescue => e
        logger.error "[FAILED] #{path}. #{e.message}. #{e.backtrace}"
      end
    end
  end
end