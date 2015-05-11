require 'daybreak'
require 'thread'
require 'irb'

module Uploader
  class Main

    include Uploader::Helpers

    def initialize(user)
      @conf = Uploader::Config.instance user
      @log = @conf.logger
      Uploader::FlickrAuth.authenticate @conf
      @db = Daybreak::DB.new @conf.db_path # HERE !!!
      @other_dbs = Dir.glob(@conf.base_dir + "/db/*.dbk").inject([]) do |dbs,other_db|
        dbs << Daybreak::DB.new(other_db) unless other_db == @conf.db_path
        dbs
      end
      @other_dbs.each { |db| @log.debug "Found other DB: #{File.basename(db.file)}" }
      @conf.other_dbs = @other_dbs
      @file_uploaders = []
      @upload_queue = Queue.new
      @crawler = nil
    end

    def close
      @crawler.exit
      gracefully_close_threads

      @log.debug "closing dbs"
      @db.close
      @other_dbs.each do |db|
        db.close
        @log.debug "closing other db #{File.basename db.file}"
      end
    end

    def gracefully_close_threads
      @upload_queue.size.times   { @upload_queue.pop }    # empty the queue
      @conf.upload_threads.times { @upload_queue << nil } # next round will kill each thread during q.pop

      sleep 1

      @log.info "making sure all threads are done"

      @file_uploaders.each do |t|
        if t.status == false
          @log.info "thread #{t.object_id} finished"
        else
          @log.info "thread #{t.object_id} is not finished, waiting..."
          t.join
        end
      end
    end

    def irb
      @conf = Uploader::Config.instance
      Uploader::FlickrAuth.authenticate(@conf)
      #db = Uploader::FileHashDB.new(@conf)
      puts "Starting irb."
      puts "Run: `@conf = Uploader::Config.instance` to get @conf"
      IRB.start
      db.close
      puts "done"
    end

    def run_uploader!
      @log.info "Starting the uploader"

      @file_uploaders = @conf.upload_threads.times.map do
        @log.info "lunching thread"
        Thread.new { Uploader::FileUploader.new(@upload_queue, @db, @log).run! }
      end

      @log.debug "file uploaders is: #{@file_uploaders}"

      @crawler = Thread.new {
        Uploader::DirCrawler.new(@db, @upload_queue, @file_uploaders).run!
      }

      @crawler.join

      # at this point we are done, but you need to call 'close' to really wrap things up
    end
  end
end
