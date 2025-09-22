module RuleEngine
  # Event dispatcher for handling rule outcomes
  # Implements Observer pattern for decoupling rule evaluation from action execution
  class EventDispatcher
    attr_reader :handlers

    def initialize
      @handlers = []
    end

    def register_handler(handler)
      raise ArgumentError, "Handler must be an ActionHandler" unless handler.is_a?(ActionHandler)
      @handlers << handler unless @handlers.include?(handler)
      self
    end

    def unregister_handler(handler)
      @handlers.delete(handler)
      self
    end

    def register_handlers(*handlers)
      handlers.each { |handler| register_handler(handler) }
      self
    end

    def clear_handlers
      @handlers.clear
      self
    end

    def dispatch(outcomes)
      return [] if outcomes.nil? || outcomes.empty?

      results = []
      outcomes = [outcomes] unless outcomes.is_a?(Array)

      outcomes.each do |outcome|
        next unless outcome.is_a?(Outcome)

        matching_handlers = @handlers.select { |handler| handler.can_handle?(outcome) }
        
        if matching_handlers.empty?
          puts "WARNING: No handlers found for outcome: #{outcome.class.name}"
          next
        end

        matching_handlers.each do |handler|
          begin
            result = handler.handle(outcome)
            results << {
              outcome: outcome,
              handler: handler,
              result: result,
              timestamp: Time.now
            }
          rescue => e
            puts "ERROR: Handler '#{handler.name}' failed to process outcome '#{outcome.class.name}': #{e.message}"
            puts e.backtrace.join("\n")
            results << {
              outcome: outcome,
              handler: handler,
              result: nil,
              error: e.message,
              timestamp: Time.now
            }
          end
        end
      end

      results
    end

    def dispatch_async(outcomes)
      # For async processing, you might want to use a background job system
      # This is a simple implementation that could be enhanced
      Thread.new do
        dispatch(outcomes)
      end
    end

    def handler_count
      @handlers.size
    end

    def handlers_for_outcome(outcome_class)
      @handlers.select { |handler| handler.can_handle?(outcome_class.new(nil)) }
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @handlers_count=#{@handlers.size}>"
    end
  end
end

