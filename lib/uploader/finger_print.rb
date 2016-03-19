require 'net/http'
require 'digest'
require 'thread'

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
      puts "DB Flush"
      @db.flush
      puts "DB Close"
      @db.close
      puts "Done"
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
      photo_pages_work_q = Queue.new
      page = 1 # We'll start at page 1
      # First we'll just find out the total number of pages
      pages = flickr.people.getPhotos(user_id: 'me', page: page).pages
      # put all pages in the queue
      pages.times { |p| photo_pages_work_q << p + 1 }
      # luanch the threads to work
      threads = @conf.upload_threads.times.map do |i|
        @log.info "lunching index fixer thread #{i}"
        Thread.new do
          begin
            until photo_pages_work_q.empty?
              fixer_thread(i, photo_pages_work_q)
            end
          rescue ThreadError => e
            @log.debug "no more pages for thread ##{i}"
          end
        end
      end

      @log.debug "Joining threads: #{threads}"
      threads.map(&:join)
    end

    def fixer_thread(thread_number, queue)
      @log.info "Fixer thread ##{thread_number} started"
      until queue.empty?
        page_number = queue.pop(true)
        @log.info "Thread #{thread_number} Working on page #{page_number}"
        tries = CountDown.new(API_RETRIES)
        begin
          photos_page = flickr.people.getPhotos(user_id: 'me', page: page_number)
        rescue => e
          retry unless tries.zero?
          raise e
        end
        find_and_fix_unindexed_photos(photos_page)
        @db.synchronize { @db.flush } # saves the data after each page
      end
      @log.info "Fixer thred ##{thread_number} is done"
    end

    # TODO: Map all cases. Delte uneeded db entries.
    # Remember we delete from flickr manually but the db update should be automatic 
    def find_and_fix_unindexed_photos(page)
      page.each_entry do |photo|
        id = photo["id"]
        @log.debug "checking db for photo id: #{id}"
        unless @db[photo["id"]] && @db[photo["id"]] != KNOWN_ERROR_HASH # didn't get photo
          # [[1]] Get the damn tags
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
          
          # [[2]] look for a tag with the hash sum of the photo (version 1)
          if hash = just_tags.find { |t| t.match V1 }
            # The photo has a tag, but it's missing from local db
            # First we'll make sure the photo is not a duplicate by looking for
            # it's sum in the DB
            sum = hash.gsub('fp1_','')
            if @db[sum]
              # This photo is a duplicate in our DB!
              # Let's make sure it's really in two places in flickr...
              # Let's call it in cause we're too coward to delete it
              @log.warn "Duplicate Photo! #{id} (this: https://www.flickr.com/photos/119737768@N08/#{id}/ and other: https://www.flickr.com/photos/119737768@N08/#{@db[sum]}/)"
            else
              @log.info "photo #{id} was not in DB; updating now"
              set_hash_and_id(hash.gsub('fp1_',''), id)
            end
          else # no tag, get photo and calc hash sum
            sizes = flickr.photos.getSizes(photo_id: id)
            original = sizes.find { |s| s["label"] == "Original" }
            unless original
              @log.warn "failed to find original copy of photo #{id}, skipping (might be a video)"
            else
              @log.debug "streaming photo into md5: (original) #{original}"
              @log.debug "streaming photo into md5: ( source ) #{original["source"]}"
              hash = uri_to_md5(URI(original["source"]))
              if @db[hash]
                @log.warn "Duplicate Photo! Unindex photo (id) in the cloud matched indexed photo (hash: #{hash}). Unindexed: #{original["source"]} Indexed: https://www.flickr.com/photos/119737768@N08/#{@db[hash]}/ Tagging it so it could later be deleted"
              else
                @log.info "photo #{id} was not index yet; got hash: #{hash}, adding to db"
                set_hash_and_id(hash, id)
              end
              set_tag_v1(hash, id)
            end
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
      tries = CountDown.new(API_RETRIES)
      @log.info "setting tag: fp1_#{hash} on photo #{id}"
      begin
        flickr.photos.addTags(photo_id: id, tags: "fp1_#{hash}")
      rescue => e
        retry unless tries.zero?
        raise e
      end
    end

    # Stream the file into MD5 and return the hexdigest
    def uri_to_md5(uri)
      tries = CountDown.new(API_RETRIES)
      begin
        md5 = Digest::MD5.new
        http = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE) # do |http|
        #http.use_ssl = true
        #http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Get.new uri
        http.request(request) do |response|
          response.read_body { |chunk| md5 << chunk }
        end
        # end
        md5.hexdigest
      rescue => e
        retry unless tries.zero?
        raise e
      end
    end

  end
end
