require 'daybreak'
require 'thread'
require 'irb'

module Uploader
  class Main

    include Uploader::Helpers

    def initialize(user)
      @conf = Uploader::Config.instance user
      Uploader::FlickrAuth.authenticate @conf
      @db = Daybreak::DB.new @conf.db_path # HERE !!!
      @other_dbs = Dir.glob(@conf.base_dir + "/db/*.dbk").inject([]) do |dbs,other_db|
        dbs << Daybreak::DB.new(other_db) unless other_db == @db
        dbs
      end
      @other_dbs.each { |db| @conf.logger.debug "Found other DB: #{File.basename(db.file)}" }
      @conf.other_dbs = @other_dbs
    end

    def close
      @conf.logger.debug "closing db"
      @db.close
      @other_dbs.each do |db|
        db.close
        @conf.logger.debug "closing other db #{File.basename db.file}"
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

      log = @conf.logger
      log.info "Starting the uploader"
      log.debug "DB: #{@db}"
      log.debug "User: #{@conf.username}"

      queue = Queue.new

      # TODO HERE !!
      # handle: "Net::ReadTimeout" withing the threads

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
