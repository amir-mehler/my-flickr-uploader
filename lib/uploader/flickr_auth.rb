require 'flickraw'
require 'yaml'

module Uploader
  class FlickrAuth

    include Uploader::Helpers

    LOGIN_TRIES = 3

    def self.authenticate(conf)
      begin
        creds = conf.flickr_creds
        # conf.logger.debug "creds are: #{creds}"

        # API creds (for this app, regardless of user)
        puts "DEBUG #{creds}  secret: #{creds["secret"]}"
        if creds["key"] && creds["secret"]
          # conf.logger.debug "Using API creds #{creds["key"]} #{creds["secret"]}"
          FlickRaw.api_key       = creds["key"]
          FlickRaw.shared_secret = creds["secret"]
        else
          raise "Error! 'secret/api_key.yml' must include { 'api-key': { 'key': 'kkk...', 'secret': 'sss...' } }"
        end

        # User creds, we cache these for every user on first use.
        if File.exist? conf.user_creds_path
          user_creds = YAML.load_file(conf.user_creds_path)["flickr"]
          # conf.logger.debug "These are the creds from the file: #{user_creds}"
          unless user_creds["access_token"] && user_creds["access_secret"]
            raise "Error! bad secret user file, better delete it and reauthorize (#{conf.user_creds_path})"
          end
          flickr.access_token  = user_creds["access_token"]
          flickr.access_secret = user_creds["access_secret"]
          tries = CountDown.new(LOGIN_TRIES)
          begin
            login = flickr.test.login
            unless login.username == conf.username
              raise "Error! got login username: #{login.username} but you provided: #{username}. Please try again with the first one: [#{login.username}] (creds are already cached)"
            end
          rescue => e
            if e.class == Net::ReadTimeout
              retry unless tries.zero?
            end
            puts "#{e.message}. Failed to login with cached creds, re-authenticating app #{user_creds["access_token"]} #{user_creds["access_secret"]}"
            verify_api_key conf.username, conf.user_creds_path
          end
        else
          # No cached creds, authenticate, login and cache
          verify_api_key conf.username, conf.user_creds_path
        end
      rescue SocketError => e
        conf.logger.error "Failed to authenticate - check network connection"
        exit 1
      rescue => e
        conf.logger.error "Authentication Error: #{e.message}"
        raise e
      end
      conf.logger.info "Successfully logged in as #{conf.username}"
    end

    def self.verify_api_key(username, user_creds_path)
      creds = {}
      token = flickr.get_request_token
      auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')
      puts "====================================================================="
      puts "Open this url in your browser to complete the authentication process:"
      puts "#{auth_url}"
      puts "====================================================================="
      puts "Paste here the number given when you complete the process:"
      verify = gets.strip
      puts "Got it. Attempting login..."
      tries = CountDown.new(LOGIN_TRIES)
      begin
        flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
        login = flickr.test.login
        creds["flickr"] = {
          "access_token"  => flickr.access_token,
          "access_secret" => flickr.access_secret
        }
        File.open(user_creds_path,'w') { |f| f.write creds.to_yaml }
        # validate user name (we first cache the access token, so we won't have to repeat this)
        unless login.username == username
          raise "Error! got login username: #{login.username} but you provided: #{username}. Please try again with the first one: [#{login.username}] (creds are already cached)"
        end
      rescue Net::ReadTimeout => e
        retry unless tries.zero?
        raise "failed to login! (make sure you pasted the code as is)"
      rescue FlickRaw::FailedResponse => e
        raise "authentication failed : #{e.msg}"
      end
    end

  end
end
