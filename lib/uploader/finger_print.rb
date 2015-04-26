require 'net/http'
require 'digest'

module Uploader
  class FingerPrint

    # To Do
    # 1. Opt: ignore existing tags (in case they require fixing)
    # 2. Opt: ignore existing DB entries (in case they require fixing)

    include Uploader::Helpers

    API_RETRIES = 3
    KNOWN_ERROR_HASH = '53cb73f74724b36bde1d9f22d3350edb'
    # version 1: 'fp1_dcfe25f0fa9811ef96cbe87c0d85d56e'
    V1 = /^fp1_\h{32}$/

    def initialize(user)
      @conf = Uploader::Config.instance user
      @log = @conf.logger

      Uploader::FlickrAuth.authenticate(@conf)

      path = "#{@conf.base_dir}/db/#{@conf.username}.dbk"
      @db = Daybreak::DB.new(path)
      @log.debug "db is #{@db}"
    end

    def close_db
      @db.flush
      @db.close
    end

    def fix_em_all!
      # Read each picture from flickr
      # # Check if photo ID is in DB
      # # Next if found; else
      # # Check for tag #fp1_<md5sum>
      # # (Use it) or (download and calc sum, then set the tags)
      # # Update the DB
      # End

      @log.info "Starting to verify and fix all fingerprints"
      @log.info "getting a list of all photos from flickr"
      # Get all photos in one list
      page = 1
      pages = flickr.people.getPhotos(user_id: 'me', page: page).pages
      while page <= pages
        tries = CountDown.new(API_RETRIES)
        begin
          photos_page = flickr.people.getPhotos(user_id: 'me', page: page)
        rescue => e
          retry unless tries.zero?
          raise e
        end
        @log.info "downloaded #{photos_page.size} photos index. Page #{page}/#{pages}"
        find_and_fix_unindexed_photos(photos_page)
        @db.synchronize { @db.flush } # saves the data after each page
        page += 1
      end
    end

    def find_and_fix_unindexed_photos(page)
      page.each_entry do |photo|
        id = photo["id"]
        @log.debug "checking db for photo id: #{id}"
        unless @db[photo["id"]] && @db[photo["id"]] != KNOWN_ERROR_HASH # didn't get photo
          just_tags = []
          tries = CountDown.new(API_RETRIES)
          begin
            tags = flickr.tags.getListPhoto(photo_id: id)
            just_tags = tags['tags'].map { |t| t['raw'] }
          rescue => e
            @log.debug "api error (tags), retry..."
            sleep 3
            retry unless tries.zero?
            @log.error "failed to get tags from flickr, skipping photo"
            next
          end
          # look for a tag with the hash sum of the photo
          # version 1:
          if hash = just_tags.find { |t| t.match V1 }
            @log.info "photo #{id} was not in DB; updating now"
            set_hash_and_id(hash.gsub('fp1_',''), id)
          else # no tag, get photo and calc hash sum
            sizes = flickr.photos.getSizes(photo_id: id)
            original = sizes.find { |s| s["label"] == "Original" }
            @log.debug "streaming photo into md5: #{original["source"]}"
            hash = uri_to_md5 URI(original["source"])
            @log.info "photo #{id} was not index yet; got hash: #{hash}, adding to db"
            set_hash_and_id(hash, id)
            set_tag_v1(hash, id)
          end
        end
      end
    end

    def set_hash_and_id(hash, id)
      @db.synchronize {
        @db[hash] = id
        @db[id] = hash
      }
    end

    def set_tag_v1(hash, id)
      @log.info "setting tag: fp1_#{hash} on photo #{id}"
      flickr.photos.addTags(photo_id: id, tags: "fp1_#{hash}")
    end

    # Stream the file into MD5 and return the hexdigest
    def uri_to_md5(uri)
      tries = CountDown.new(API_RETRIES)
      begin
        md5 = Digest::MD5.new
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          request = Net::HTTP::Get.new uri
          http.request(request) do |response|
            response.read_body { |chunk| md5 << chunk }
          end
        end
        md5.hexdigest
      rescue => e
        retry unless tries.zero?
        raise e
      end
    end

  end
end
