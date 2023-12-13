module Cauchy
  module Elastic

    class ElasticError < StandardError
      def initialize(message = nil)
        super
      end
    end

    class IndexAlreadyExistsError < ElasticError
      def initialize(name)
        super("Index \"#{name}\" already exists")
      end
    end

    class CannotUpdateNonDynamicSettingsError < ElasticError
      def initialize(name)
        super("Index \"#{name}\" cannot be updated while open.")
      end
    end

    class Index

      attr_reader :server, :name

      def initialize(server, name)
        @server = server
        @name = name
      end

      def exists?
        server.indices.exists? index: name
      end

      def aliases
        get 'alias'
      end

      def mappings
        get('mapping')[name]['mappings']
      rescue
        {}
      end

      def settings
        get('settings')[name]['settings']['index']
      rescue
        {}
      end

      def alias=(alias_name)
        server.indices.put_alias index: name, name: alias_name
      end

      def mappings=(mappings)
        mappings.each do |type, mapping|
          server.indices.put_mapping index: name, body: mapping
        end
      end

      def settings=(settings)
        server.indices.put_settings index: name, body: settings
      rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
        if e.message =~ /update non dynamic settings/
          raise CannotUpdateNonDynamicSettingsError.new(name)
        else
          raise
        end
      end

      def create(settings: {}, mappings: {})
        server.indices.create index: name,
          body: { settings: settings, mappings: mappings }
      rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
        if e.message =~ /IndexAlreadyExists/
          raise IndexAlreadyExistsError.new(name)
        else
          raise
        end
      end

      def delete
        server.indices.delete index: name
      end

      def open
        server.indices.open index: name
      end

      def close
        server.indices.close index: name
      end

      def scroll(options = {})
        options = { index: name, search_type: 'scan', scroll: '5m', size: 100 }.merge(options)
        scroll_id = server.search(options)['_scroll_id']
        begin
          results = server.scroll(scroll_id: scroll_id, scroll: options[:scroll])
          documents, scroll_id = results['hits']['hits'], results['_scroll_id']
          yield documents, results['hits']['total'] if documents.any?
        end while documents.size > 0
      end

      private

      def get(resource)
        server.indices.send(['get', resource].join('_').to_sym, index: name)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end

    end
  end
end
