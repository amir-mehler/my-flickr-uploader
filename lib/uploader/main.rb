require 'daybreak'
require 'thread'
require 'irb'

module Uploader
  class Main

    include Uploader::Helpers

    def initialize
      @conf = Uploader::Config.instance
      Uploader::FlickrAuth.authenticate(@conf)
      @db = Daybreak::DB.new @conf.db_path
    end

    def close
      @conf.logger.debug "closing db"
      @db.close
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

      # write dir disk crawler (use dir mod time and store in db)
      # make sure the uploaders tag the photos

      log = @conf.logger
      log.info "Starting the uploader"
      log.debug "DB: #{@db}"
      log.debug "User: #{@conf.username}"

      queue = Queue.new

      file_uploaders = @conf.upload_threads.times.map do
        log.info "lunching thread"
        Thread.new { Uploader::FileUploader.new(queue, @db, log).run! }
      end

      Uploader::DirCrawler.new(@db, queue).run!

      sleep 1
      log.info "crawler finished, all upload in queue"

      while queue.size > 0 do
        sleep 5
        @log.info "#{queue.size} photos pending upload..."
      end

      @conf.upload_threads.times do
        queue << nil # next round will kill each thread during q.pop
      end

      sleep 1

      log.info "making sure all threads are done"

      file_uploaders.each do |t|
        if t.status == false
          log.info "thread #{t.object_id} finished"
        else
          log.info "thread #{t.object_id} is not finished, waiting..."
          t.join
        end
      end

      log.info "-- fin --"
    end
  end
end
