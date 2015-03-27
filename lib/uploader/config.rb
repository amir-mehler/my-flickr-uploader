require 'singleton'
require 'yaml'
require 'logger'
require 'daybreak'

module Uploader
  class Config
    include Singleton

    # Constants
    CREDS_YML = 'flickr_creds.yml'
    WORK_DIRS = 'work_dirs.yml'    # Directories to scan and upload. Yaml: "work_dirs" = [ 'dir', ... ]
    IMAGE_EXTENSIONS = %w( jpg jpeg gif bmp png jfif exif tiff tif rif bpg mov mp4 raw)

    attr_reader :image_extensions, :work_dirs, :flickr_creds, :logger
    attr_reader :upload_threads, :username, :base_dir, :db_path

    def initialize
      @base_dir = File.expand_path("../../../", __FILE__)
      @work_dirs = YAML.load_file(@base_dir + "/config/" + WORK_DIRS)
      @flickr_creds = @base_dir + "/config/" + CREDS_YML
      @image_extensions = IMAGE_EXTENSIONS
      @upload_threads = 1
      @username = '' # will be available after authentication
      @db_path = nil

#      @logger = Logger.new(@base_dir + "/log/uploader_log", "daily")
      @logger = Logger.new(STDOUT)
      @logger.datetime_format = '%d-%m-%Y %H:%M:%S'
      @logger.level = Logger::DEBUG

      @logger.info "<<< initialized config instance >>>"
    end

    def set_username(n)
      @username.empty? && @username = n
      @db_path ||= "#{@base_dir}/db/#{@username}.dbk"
    end

  end
end