# First Authentication

require 'flickraw'

FlickRaw.api_key="e9959b77d2886cc1e0428a5130236a34"
FlickRaw.shared_secret="d711ec2dc016d6af"

token = flickr.get_request_token
auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')


APP_VERIFICATION = '909-483-442'
puts "Open this url in your process to complete the authication process : #{auth_url}"
puts "Copy here the number given when you complete the process."
verify = gets.strip


begin
  flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
  login = flickr.test.login
  puts "You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{flickr.access_secret}"
  # You are now authenticated as naamap with token 72157650612410139-df770da61323d9c2 and secret 9c815bc18fcd54a5
rescue FlickRaw::FailedResponse => e
  puts "Authentication failed : #{e.msg}"
end

# Login with cached token

require 'flickraw'

FlickRaw.api_key="e9959b77d2886cc1e0428a5130236a34"
FlickRaw.shared_secret="d711ec2dc016d6af"

flickr.access_token = "72157650612410139-df770da61323d9c2"
flickr.access_secret = "9c815bc18fcd54a5"

login = flickr.test.login

# upload

flickr.upload_photo PHOTO_PATH, :title => "Title", :description => "This is the description"