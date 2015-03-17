require 'net/http'
require 'digest'

module Uploader
  class FingerPrint

    include Uploader::Helpers

    def self.fix_em_all!
      # Read each picture from flickr
      # # Check if photo id is in DB
      # # Next if found; else
      # # Check for tags #fp_v1 and #<actual-md5sum>
      # # (Use hash tag) or (download and calc sum, then set the tags)
      # # Update the DB
      # End

      @conf = Uploader::Config.instance
      log = @conf.logger
      log.info "Starting to verify and fix all fingerprints"
      get_photos_retries = 3

      Uploader::FlickrAuth.authenticate(@conf)

      db = @conf.db

      log.info "Getting a list of all photos from flickr"
      # Get all photos in one list
      page = 1
      pages = flickr.people.getPhotos(user_id: 'me', page: page).pages
      while page <= pages
        tries = CountDown.new(get_photos_retries)
        begin
          photos_page = flickr.people.getPhotos(user_id: 'me', page: page)
          # tags = flickr.tags.getListPhoto(photo_id: photos_page[0]["id"])
        rescue => e
          retry unless tries.zero?
          raise e
        end
        log.info "Got #{photos_page.size} photos. Page #{page}/#{pages}"
        need_to_index = find_unindexed_photos(photos_page)
        break
        # log.info "One tag is: #{tags["tags"][0]["raw"]}" if tags
        page += 1
      end
    end

    def self.find_unindexed_photos(page)
      page.each_entry do |photo|
        id = photo["id"]
        puts "got: #{id} looking in db"
        unless @conf.db[photo["id"]] # didn't get photo # TODO check the next 15 lines # TODO make these methods not private
          # try tags
          tags = flickr.tags.getListPhoto(photo_id: photos_page[0]["id"])
          just_tags = tags['tags'].map { |t| t['raw'] }
          # version 1: 'fp1_dcfe25f0fa9811ef96cbe87c0d85d56e'
          v1 = /^fp1_\h{32}$/
          if hash = just_tags.find { |t| t.match(v1) }
            set_hash_and_id(hash.gsub('fp1_',''), id)
          else
            # get photo hash sum
            sizes = flickr.photos.getSizes(photo_id: id)
            original = sizes.find { |s| s["label"] == "Original" }
            hash = uri_to_md5 URI(original["source"])
            set_hash_and_id(hash, id)
          end
          break
        end
      end

      def uri_to_md5(uri)
        # Stream the file into MD5 and return the hexdigest
        # TODO: 3 tries
        md5 = Digest::MD5.new
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new uri
          http.request request do |response|
            response.read_body do |chunk|
              md5 << chunk
            end
          end
        end
        md5.hexdigest
      end

    end
  end
