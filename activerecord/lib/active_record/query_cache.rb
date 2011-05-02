require 'active_support/core_ext/object/blank'

module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      def cache(&block)
        if ActiveRecord::Base.configurations.blank?
          yield
        else
          connection.cache(&block)
        end
      end

      # Disable the query cache within the block if Active Record is configured.
      def uncached(&block)
        if ActiveRecord::Base.configurations.blank?
          yield
        else
          connection.uncached(&block)
        end
      end
    end

    def initialize(app)
      @app = app
    end

    class BodyProxy # :nodoc:
      def initialize(original_cache_value, target)
        @original_cache_value = original_cache_value
        @target               = target
      end

      def each(&block)
        @target.each(&block)
      end

      def close
        @target.close if @target.respond_to?(:close)
      ensure
        unless @original_cache_value
          ActiveRecord::Base.connection.disable_query_cache!
        end
      end
    end

    def call(env)
      old = ActiveRecord::Base.connection.query_cache_enabled
      ActiveRecord::Base.connection.enable_query_cache!

      status, headers, body = @app.call(env)
      [status, headers, BodyProxy.new(old, body)]
    end
  end
end
