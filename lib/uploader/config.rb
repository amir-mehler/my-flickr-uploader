#require 'singleton'
require 'yaml'
require 'logger'
require 'daybreak'

module Uploader
  class Config
    # include Singleton

    # Constants
    IMAGE_EXTENSIONS = %w( jpg jpeg gif bmp png jfif exif tiff tif rif bpg mov mp4 raw)

    attr_reader :image_extensions, :work_dirs, :flickr_creds, :logger
    attr_reader :upload_threads, :username, :base_dir, :db_path, :conf_file

    # singleton with parameter
    @@singleton = nil
    @@mutex = Mutex.new

    def self.instance(conf_file=nil)
      # return @@singleton if @@singleton
      @@mutex.synchronize {
        return @@singleton if @@singleton
        @@singleton = new(conf_file)
      }
      @@singleton
    end

    def set_username(n)
      @username.empty? && @username = n
      @db_path ||= "#{@base_dir}/db/#{@username}.dbk"
    end

    private

    def initialize(conf_file)
      @conf_file = conf_file
      @base_dir = File.expand_path("../../../", __FILE__)
      @user_conf = YAML.load_file(@conf_file)
      @work_dirs = @user_conf["work_dirs"]
      @flickr_creds = @user_conf["flickr"]
      @image_extensions = IMAGE_EXTENSIONS
      @upload_threads = 15
      @username = '' # will be available after authentication
      @db_path = nil

      @logger = Logger.new(STDOUT) #@logger = Logger.new(@base_dir + "/log/uploader_log", "daily")
      @logger.datetime_format = '%d-%m-%Y %H:%M:%S'
      @logger.level = Logger::DEBUG

      @logger.info "<<< initialized config instance >>>"
    end

  end
end