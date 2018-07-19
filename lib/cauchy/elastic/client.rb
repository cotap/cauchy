require 'elasticsearch'

require 'cauchy/elastic/index'

module Cauchy
  module Elastic
    class Client

      attr_reader :server

      def initialize(config)
        @server = Elasticsearch::Client.new(config)
      end

      def index(name)
        Index.new(server, name)
      end

      def reindex(body)
        server.reindex body: body
      end

      def update_aliases(body)
        server.indices.update_aliases body: body
      end

    end
  end
end
