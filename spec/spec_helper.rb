$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'elasticsearch'
require 'pp'
require 'pry'
require 'rspec/its'

require 'cauchy'

Cauchy.logger = Logger.new('/dev/null')

def elasticsearch_config
  {
    urls: ENV.fetch(
      'ELASTICSEARCH_HOSTS', 'http://localhost:9400,http://127.0.0.1:9400'
    )
  }
end

def elasticsearch
  @elasticsearch ||= Elasticsearch::Client.new(elasticsearch_config)
end