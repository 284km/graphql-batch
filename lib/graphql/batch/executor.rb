module GraphQL::Batch
  class Executor
    THREAD_KEY = :"#{name}.batched_queries"
    private_constant :THREAD_KEY

    def self.current
      Thread.current[THREAD_KEY]
    end

    def self.current=(executor)
      Thread.current[THREAD_KEY] = executor
    end

    # Set to true when performing a batch query, otherwise, it is false.
    #
    # Can be used to detect unbatched queries in an ActiveSupport::Notifications.subscribe block.
    attr_reader :loading

    def initialize
      @loaders = {}
      @loading = false
    end

    def loader(key)
      @loaders[key] ||= yield.tap do |loader|
        loader.executor = self
        loader.loader_key = key
      end
    end

    def resolve(loader)
      was_loading = @loading
      @loading = true
      loader.resolve
    ensure
      @loading = was_loading
    end

    def tick
      resolve(@loaders.shift.last)
    end

    def wait_all
      tick until @loaders.empty?
    end

    def clear
      @loaders.clear
    end

    def around_promise_callbacks
      # We need to set #loading to false so that any queries that happen in the promise
      # callback aren't interpreted as being performed in GraphQL::Batch::Loader#perform
      was_loading = @loading
      @loading = false
      yield
    ensure
      @loading = was_loading
    end
  end
end
