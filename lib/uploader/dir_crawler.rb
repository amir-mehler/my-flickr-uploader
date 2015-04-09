require 'digest'

module Uploader
  class DirCrawler

    # To Do
    # 1. The account name comes from the conf, one db per account
    # 2. Each dir in conf is the starting point for it's own tree
    #    It means all DB entries for it will look like:
    #    D_DRIVE/photos
    #    D_DRIVE/photos/jan_2013 [/etc..]
    # 3. The dir entries are used for saving their status:
    #    key: path, value: { last_modification: epoch, last_successfull_scan: epoch}
    #    in any case the dir was modified, we set the last_successfull_scan to 'never' and scan again
    #    if (last_successfull_scan < last_modification) we scan again

    # Wish list
    # Add an entry for each dir that describe all of it's sub dirs (one level)
    # This will allow us to keep track of deleted dirs and remove thier markers from the DB
    # Opt: validate that each photo found in DB is really in flickr with matching ID and hash tag

    def initialize(db, queue)
      @conf = Uploader::Config.instance
      @db   = db
      @q    = queue
      @dirs = @conf.work_dirs
      @log  = @conf.logger
      @image_ext = Uploader::Config::IMAGE_EXTENSIONS
    end

    def find_in_dbs(sum)
      # check user's db, and all other dbs.
      id = @db[sum]
      unless id
        @conf.other_dbs.find do |db|
          break if id = db[sum]
        end
      end
      id
    end

    def is_picture?(file)
      m = file.match(/\w+\.(?<ext>\w{3}\w?)$/)
      return m.nil? ? false : @image_ext.include?(m["ext"].downcase)
    end

    def upload_photo(file, sum, base_dir)
      while @q.size > (@conf.upload_threads * 2)
        @log.debug "waiting for uploaders..."
        sleep 5
      end
      @q << { file: file, sum: sum, basedir: base_dir }
    end

    def run!
      begin
        @dirs.each do |d|
          raise "Dir path must start at root. '/' char." unless d.match /^\//
          raise "Dir does not exist! (#{d})" unless File.directory? d
          d.gsub!(/\/$/,'') if d.length > 2 # remove '/' postfix
          run_on_dir d, d
        end
      rescue => e
        while @q.size > 0
          @log.info "waiting for current uploads to finish before quiting (^C to stop)"
          sleep 3
        end
      end
    end

    def run_on_dir(dir, base_dir)
      check_files = true
      # Check if the dir was modified since the last time we saw it
      curr_mtime = File.stat(dir).mtime.to_i
      if last_read = @db[dir]
        # we saw it before, let's see if it changed
        if last_read['last_modification'] &&
          last_read['last_modification'] == curr_mtime &&
          last_read['last_successfull_scan'] &&
          last_read['last_successfull_scan'] != 'never'
          # nothing changed; no need to check each file here
          check_files = false
          @log.info("skipping dir: #{dir} since it wasn't changed since the last run")
        end
      end
      # We first scan all files in current dir, mark it done, and then descend deeper
      if check_files
        # We always reset the marker when we start a scan
        @log.info("crawling through dir: #{dir}")
        @db[dir] = { 'last_modification' => curr_mtime, 'last_successfull_scan' => 'never' }
        Dir.glob(dir + "/*").each do |file|
          next unless File.file?(file) && is_picture?(file)
          @log.debug "checking out #{File.basename(file)}"
          sum = Digest::MD5.file(file).hexdigest
          if id = find_in_dbs(sum)
            @log.debug "picture already in db"
            # Validate id is in flickr? (should be an option, but means you can't just delete from flickr)
            next
          else
            upload_photo(file, sum, base_dir)
          end
        end
        @db[dir] = { 'last_modification' => curr_mtime, 'last_successfull_scan' => Time.now.to_i }
        @log.info("finished with files in dir #{dir}")
      end
      # after the files, we descend deeper into directories
      Dir.glob(dir + "/*").each do |sub_dir|
        run_on_dir(sub_dir, base_dir) if File.directory? sub_dir
      end
      @log.info("finished recursive descent into dir #{dir}")
    end

  end
end