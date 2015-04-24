module Uploader
  class FileUploader

    include Uploader::Helpers

    UPLOAD_TRIES = 5
    TIMEOUT_MSG = "upload_timeout"

    def initialize(queue, db, log)
      @q   = queue
      @db  = db
      @log = log
      @temp_file = "/tmp/temp_file.#{Thread.current.object_id}"
    end

    # Pop from queue, try to upload to Flickr. That's it.
    def run!
      @log.info "uploder thread started! (#{Thread.current.object_id})"
      begin
        while i = @q.pop
          @log.debug "starting upload of #{File.basename(i[:file])} #{i[:sum]}"
          upload i[:file], i[:sum], i[:basedir]
        end
        @log.info "uploader thread done! (#{Thread.current.object_id})"
      rescue => e
        @db.synchronize { @db.flush }
        if (e.class == ThreadError) && (e.message == TIMEOUT_MSG)
          @log.error "upload timeouts. this thread will die now (#{Thread.current.object_id})"
        else
          @log.error "thread finished with exception: #{e.message} (#{Thread.current.object_id})"
        end
      end
    end

    def upload(file, sum, base_dir)
      id = 'error' # so we could dig out errors in the db
      tries = CountDown.new(UPLOAD_TRIES)
      begin
        # this extracts all of the dir names above base_dir and translates to english
        path_tags = (File.dirname(file).split('/') - base_dir.split('/')).map { |str|
                      trn = translate str
                    }.join(' ')
        tags = path_tags + " fp1_#{sum}" # mind the spaces
        title = translate(File.basename(file))
        args = {
          title: title,
          tags: tags,
          is_public: 0,
          is_friend: 0,
          is_family: 1,
          safety_level: 1, # 1 for Safe, 2 for Moderate, and 3 for Restricted
          hidden: 2,
          description: ''
        }
        @log.debug "start actual upload with args: #{args}"
        id = flickr.upload_photo file, args
        @log.info "[UPLOADED] name: #{title}, id: #{id}"
      rescue Encoding::UndefinedConversionError => e
        # upload file under alias name
        File.delete(@temp_file) if File.exist? @temp_file
        File.symlink file, @temp_file
        id = flickr.upload_photo @temp_file, args
        @log.info "[UPLOADED symlink] name: #{title}, id: #{id}"
      rescue Net::ReadTimeout => e
        @log.error "upload timeout (retrying)"
        retry unless tries.zero?
        raise ThreadError, TIMEOUT_MSG
      rescue => e
        @log.error "[FAILED upload] #{file}. Message: #{e.message}. Class: #{e.class}"
        @log.error e.backtrace.join("\n")
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