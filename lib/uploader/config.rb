require 'yaml'
require 'logger'
require 'daybreak'

module Uploader
  class Config

    # Constants
    IMAGE_EXTENSIONS = %w(jpg jpeg gif bmp png jfif exif tiff tif rif bpg mov mp4 raw)

    attr_reader :image_extensions, :work_dirs, :flickr_creds, :logger, :skip_dirs
    attr_reader :upload_threads, :username, :base_dir, :db_path, :conf_file
    attr_accessor :other_dbs, :user_creds_path

    # Singleton with parameter
    @@singleton = nil
    @@mutex = Mutex.new

    def self.instance(user=nil)
      @@mutex.synchronize {
        return @@singleton if @@singleton
        @@singleton = new(user)
      }
      @@singleton
    end

    private

    def initialize(user)
      @username = user
      @base_dir  = File.expand_path("../../../", __FILE__)
      @user_creds_path = @base_dir + "/secret/#{user}.yml"
      config_from_file = YAML.load_file(@base_dir + "/config/#{user}.yml")
      @work_dirs = config_from_file["work_dirs"]
      @skip_dirs = config_from_file["skip_dirs"]
      @flickr_creds = YAML.load_file(@base_dir + "/secret/api_key.yml")["api-key"]

      @image_extensions = IMAGE_EXTENSIONS
      @upload_threads = 15

      @db_path = "#{@base_dir}/db/#{@username}.dbk"
      @other_dbs = []

      log_file = File.open(@base_dir + "/log/uploader_log", 'a')
#      @logger = Logger.new Uploader::MultiIO.new(STDOUT, log_file), "daily"
      @logger = Logger.new STDOUT
      @logger.datetime_format = '%d-%m-%Y %H:%M:%S'
      @logger.level = Logger::DEBUG

      # delete old temp files
      Dir.glob("/tmp/temp_file.*").each { |f| File.delete f }

      @logger.info "<<< initialized config instance >>>"
    end

  end
end