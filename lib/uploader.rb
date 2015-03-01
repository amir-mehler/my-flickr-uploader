require 'bundler/setup'

module Uploader; end

Dir[File.expand_path("../uploader/*.rb",__FILE__)].each do |file|
  require file
end
