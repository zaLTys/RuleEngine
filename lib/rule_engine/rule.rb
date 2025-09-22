module RuleEngine
  # Represents a single business rule with condition and outcomes
  class Rule
    attr_reader :name, :priority, :enabled, :metadata

    def initialize(name:, priority: 0, condition:, outcomes: [], enabled: true, metadata: {})
      @name = name.to_s
      @priority = priority.to_i
      @condition = condition
      @outcomes = outcomes.is_a?(Array) ? outcomes : [outcomes]
      @enabled = enabled
      @metadata = metadata.freeze
      @next_rule = nil
    end

    # Link rules to form a chain (Chain of Responsibility pattern)
    def next_rule=(rule)
      @next_rule = rule
    end

    def next_rule
      @next_rule
    end

    def enabled?
      @enabled
    end

    def disabled?
      !@enabled
    end

    def enable!
      @enabled = true
    end

    def disable!
      @enabled = false
    end

    # Evaluate the rule and collect outcomes
    def evaluate(context, strategy: :collect_all, collected: [])
      return collected unless enabled?

      begin
        if @condition.call(context)
          # Build outcome objects
          @outcomes.each do |outcome_lambda|
            outcome = outcome_lambda.call(context)
            collected << outcome if outcome
          end

          # If strategy is first_match, return immediately
          return collected if strategy == :first_match
        end
      rescue => e
        # Log error but continue with next rule
        puts "ERROR: Rule '#{@name}' evaluation failed: #{e.message}"
        puts e.backtrace.join("\n")
      end

      # Pass to next rule in the chain
      if @next_rule
        @next_rule.evaluate(context, strategy: strategy, collected: collected)
      else
        collected
      end
    end

    def to_h
      {
        name: @name,
        priority: @priority,
        enabled: @enabled,
        metadata: @metadata,
        outcomes_count: @outcomes.length
      }
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @name=#{@name} @priority=#{@priority} @enabled=#{@enabled}>"
    end
  end
end

