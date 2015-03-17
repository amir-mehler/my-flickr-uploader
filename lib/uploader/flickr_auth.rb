require 'flickraw'

module Uploader
  class FlickrAuth

    def self.verify_api_key(path_to_yaml)
      creds = YAML.load_file path_to_yaml
      token = flickr.get_request_token
      auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')
      puts "Open this url in your process to complete the authication process : #{auth_url}"
      puts "Paste here the number given when you complete the process."
      verify = gets.strip
      flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
      tries = 3
      begin
        login = flickr.test.login
        creds = {
          "flickr" => {
            "api_key"       => creds["flickr"]["api_key"],
            "shared_secret" => creds["flickr"]["shared_secret"],
            "access_token"  => flickr.access_token,
            "access_secret" => flickr.access_secret
          }
        }
        File.open(path_to_yaml,'w') { |f| f.write creds.to_yaml }
      rescue Net::ReadTimeout => e
        retry unless (tries-=1).zero?
      rescue FlickRaw::FailedResponse => e
        raise "authentication failed : #{e.msg}"
      end
    end

    def self.authenticate(conf)
      begin
        unless File.exists? conf.flickr_creds
          raise "expected to find conf file here: #{conf.flickr_creds}"
        end

        creds = YAML.load_file conf.flickr_creds

        conf.logger.debug "creds are: #{creds}"

        if creds["flickr"]["api_key"] && creds["flickr"]["shared_secret"]
          FlickRaw.api_key       = creds["flickr"]["api_key"]
          FlickRaw.shared_secret = creds["flickr"]["shared_secret"]
        else
          raise "conf file must include api_key and shared_secret"
        end

        if creds["flickr"]["access_token"] && creds["flickr"]["access_secret"]
          flickr.access_token    = creds["flickr"]["access_token"]
          flickr.access_secret   = creds["flickr"]["access_secret"]
          tries = 3
          begin
            login = flickr.test.login
            conf.set_username(login.username)
          rescue Net::ReadTimeout => e
            retry unless (tries-=1).zero?
          rescue => e
            conf.logger.error "failed to login with cached creds, re-authenticating app"
            verify_api_key conf.flickr_creds
          end
        else
          puts "debug: got no token..."
          verify_api_key conf.flickr_creds
        end
      rescue => e
        conf.logger.error "Authentication Error: #{e.message}"
        raise e
      end
      conf.logger.info "Successfully logged in as #{login.username}"
    end
  end
end