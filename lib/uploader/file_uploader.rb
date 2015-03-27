module Uploader
  class FileUploader

    def initialize(queue, db, log)
      @q   = queue
      @db  = db
      @log = log
    end

    def run!
      @log.info "uploder thread started! (#{Thread.current.object_id})"
      begin
        while i = @q.pop
          @log.debug "starting upload of #{File.basename(i[:file])} #{i[:sum]}"
          upload i[:file], i[:sum], i[:basedir]
        end
      rescue => e
        @log.error "Thread finished with exception: #{e.message}"
        @db.synchronize { @db.flush }
        raise e
      end
      sleep rand(10) # for debug
      @log.info "uploader thread done! (#{Thread.current.object_id})"
    end

    def upload(file, sum, base_dir)
      id = 'error' # so we could dig out errors in the db
      begin
        # this extracts all of the dir names above base_dir
        path_tags = (File.dirname(file).split('/') - base_dir.split('/')).join(' ')
        tags = path_tags + " fp1_#{sum}" # mind the spaces
        args = {
          title: File.basename(file),
          tags: tags,
          is_public: 0,
          is_friend: 0,
          is_family: 1,
          safety_level: 2,
          hidden: 2,
          description: ''
        }
        id = flickr.upload_photo file, args
        @log.info "[UPLOADED] name: #{file}, id: #{id}"
      rescue => e
        @log.error "[FAILED upload] #{file}. #{e.message}."
        raise e
      end
      # only if upload was ok we update the db
      begin
        @db.synchronize {
          @db[sum] = id
          @db[id] = sum
        }
      rescue => e
        @log.error "[FAILED db insert] of '#{sum}'"
        raise e
      end
    end
  end
end