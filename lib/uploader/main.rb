require 'thread'
require 'flickraw'

module Uploader
  class Main
    def self.run!
      @conf = Uploader::Config.instance
      log = @conf.logger
      log.info "Starting the uploader"

      FlickrAuth.authenticate(@conf)

      db = Uploader::FileHashDB.new(@conf)

      queue = Queue.new

      file_uploaders = []
      @conf.upload_threads.times do
        file_uploaders << Thread.new { Uploader::FileUploader.run!(queue, db, log) }
      end

      Uploader::DiskCrawler.new.(@conf, cache, flickr).run!

      log.info "finished scanning all files"

      # TODO now send nils to kill uploaders and wait
    end
  end
end
