require 'logger'

module RuleEngine
  # Main rule engine class that orchestrates rule evaluation
  class RuleEngine
    attr_reader :rule_sets, :event_dispatcher, :transaction_manager, :logger

    def initialize(rule_sets: {}, event_dispatcher: nil, transaction_manager: nil, logger: nil)
      @rule_sets = rule_sets
      @event_dispatcher = event_dispatcher || EventDispatcher.new
      @transaction_manager = transaction_manager || TransactionManager.new
      @logger = logger || Logger.new(STDOUT)
    end

    # Add a rule set
    def add_rule_set(rule_set)
      raise ArgumentError, "RuleSet must be a RuleEngine::RuleSet" unless rule_set.is_a?(RuleSet)
      @rule_sets[rule_set.name] = rule_set
      self
    end

    # Remove a rule set
    def remove_rule_set(name)
      @rule_sets.delete(name.to_s)
      self
    end

    # Get a rule set by name
    def rule_set(name)
      @rule_sets[name.to_s]
    end

    # Evaluate rules against a context
    def evaluate(rule_set_name, context, options = {})
      rule_set = @rule_sets[rule_set_name.to_s]
      raise RuleSetNotFoundError, "Rule set '#{rule_set_name}' not found" unless rule_set

      # Use custom strategy if provided
      strategy = options[:strategy]
      if strategy.is_a?(Symbol)
        strategy = case strategy
                   when :collect_all then EvaluationStrategy::CollectAll
                   when :first_match then EvaluationStrategy::FirstMatch
                   else EvaluationStrategy::CollectAll
                   end
      end

      # Execute within transaction if requested
      if options[:transaction_id]
        @transaction_manager.execute_in_transaction(options[:transaction_id]) do
          _evaluate_with_strategy(rule_set, context, strategy, options)
        end
      else
        _evaluate_with_strategy(rule_set, context, strategy, options)
      end
    end

    # Evaluate and dispatch outcomes
    def evaluate_and_dispatch(rule_set_name, context, options = {})
      outcomes = evaluate(rule_set_name, context, options)
      
      if options[:dispatch] != false
        dispatch_results = @event_dispatcher.dispatch(outcomes)
        {
          outcomes: outcomes,
          dispatch_results: dispatch_results
        }
      else
        { outcomes: outcomes }
      end
    end

    # Register action handlers
    def register_handlers(*handlers)
      @event_dispatcher.register_handlers(*handlers)
      self
    end

    # Get all rule set names
    def rule_set_names
      @rule_sets.keys
    end

    # Get statistics about the engine
    def stats
      {
        rule_sets_count: @rule_sets.size,
        total_rules: @rule_sets.values.sum(&:size),
        enabled_rules: @rule_sets.values.sum { |rs| rs.enabled_rules.size },
        handlers_count: @event_dispatcher.handler_count,
        active_transactions: @transaction_manager.active_transaction_count
      }
    end

    # Load rules from configuration
    def load_from_config(config_path)
      loader = ConfigurationLoader.new
      loaded_rule_sets = loader.load_from_file(config_path)
      
      loaded_rule_sets.each do |rule_set|
        add_rule_set(rule_set)
      end
      
      self
    end

    private

    def _evaluate_with_strategy(rule_set, context, strategy, options)
      if strategy
        strategy.evaluate(rule_set, context)
      else
        rule_set.evaluate(context)
      end
    end
  end

  # Module-level logger
  def self.logger
    @logger ||= Logger.new(STDOUT).tap do |logger|
      logger.level = Logger::INFO
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      end
    end
  end

  def self.logger=(logger)
    @logger = logger
  end
end

