
module Uploader
  class FingerPrint

    include Uploader::Helpers

    def self.fix_em_all!
      # Read each picture from flickr
      # # Check for tags #fp_v1 and #<actual-md5sum>
      # # Next if found; else
      # # Download and calc sum
      # # Set the tags
      # End

      @conf = Uploader::Config.instance
      log = @conf.logger
      log.info "Starting to verify and fix all fingerprints"
      get_photos_retries = 3

      Uploader::FlickrAuth.authenticate(@conf)
      db = Uploader::FileHashDB.new(@conf)

      log.info "Getting a list of all photos from flickr"
      # Get all photos in one list
      page = 1
      pages = flickr.people.getPhotos(user_id: 'me', page: page).pages
      while page <= pages
        tries = CountDown.new(get_photos_retries)
        begin
          photos_page = flickr.people.getPhotos(user_id: 'me', page: page)
          tags = flickr.tags.getListPhoto(photo_id: photos_page[0]["id"])
        rescue => e
          retry unless tries.zero?
          raise e
        end
        log.info "Got #{photos_page.size} photos. Page #{page}/#{pages}"
        # log.info "One tag is: #{tags["tags"][0]["raw"]}" if tags
        page += 1
      end
    end
  end
end
