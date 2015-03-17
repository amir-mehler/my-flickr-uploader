require 'thread'
require 'irb'

module Uploader

  class Main

    def irb
      @conf = Uploader::Config.instance
      Uploader::FlickrAuth.authenticate(@conf)
      db = Uploader::FileHashDB.new(@conf)
      puts "Starting irb."
      puts "Run: `@conf = Uploader::Config.instance` to get @conf"
      IRB.start
      db.close
      puts "done"
    end

    def self.run!
      @conf = Uploader::Config.instance
      log = @conf.logger
      log.info "Starting the uploader"

      Uploader::FlickrAuth.authenticate(@conf)

      db = Uploader::FileHashDB.new(@conf)

      queue = Queue.new

      file_uploaders = @conf.upload_threads.times.map do
        log.info "lunching thread"
        Thread.new { Uploader::FileUploader.run!(queue, db, log) }
      end

      # Uploader::DiskCrawler.new.(@conf, cache, flickr).run! # todo

      sleep 1
      log.info "finished scanning all files"

      @conf.upload_threads.times do
        queue << nil # this kills the threads during q.pop
      end

      sleep 1
      log.info "make sure all threads are dead"
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
