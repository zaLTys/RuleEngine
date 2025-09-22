module RuleEngine
  # Strategy pattern for different rule evaluation approaches
  module EvaluationStrategy
    # Evaluate all matching rules and collect all outcomes
    class CollectAll
      def self.evaluate(rule_set, context)
        rule_set.evaluate(context)
      end
    end

    # Stop at the first matching rule
    class FirstMatch
      def self.evaluate(rule_set, context)
        chain = rule_set.to_chain
        return [] unless chain

        chain.evaluate(context, strategy: :first_match, collected: [])
      end
    end

    # Evaluate rules until a specific outcome type is produced
    class StopOnOutcome
      def initialize(outcome_class)
        @outcome_class = outcome_class
      end

      def evaluate(rule_set, context)
        chain = rule_set.to_chain
        return [] unless chain

        collected = []
        current_rule = chain

        while current_rule
          break unless current_rule.enabled?

          begin
            if current_rule.instance_variable_get(:@condition).call(context)
              outcomes = current_rule.instance_variable_get(:@outcomes)
              outcomes.each do |outcome_lambda|
                outcome = outcome_lambda.call(context)
                collected << outcome if outcome
                return collected if outcome.is_a?(@outcome_class)
              end
            end
          rescue => e
            RuleEngine.logger.error("Rule '#{current_rule.name}' evaluation failed: #{e.message}")
          end

          current_rule = current_rule.next_rule
        end

        collected
      end
    end

    # Evaluate rules with a maximum number of outcomes
    class LimitOutcomes
      def initialize(max_outcomes)
        @max_outcomes = max_outcomes
      end

      def evaluate(rule_set, context)
        chain = rule_set.to_chain
        return [] unless chain

        collected = []
        current_rule = chain

        while current_rule && collected.size < @max_outcomes
          break unless current_rule.enabled?

          begin
            if current_rule.instance_variable_get(:@condition).call(context)
              outcomes = current_rule.instance_variable_get(:@outcomes)
              outcomes.each do |outcome_lambda|
                break if collected.size >= @max_outcomes
                outcome = outcome_lambda.call(context)
                collected << outcome if outcome
              end
            end
          rescue => e
            RuleEngine.logger.error("Rule '#{current_rule.name}' evaluation failed: #{e.message}")
          end

          current_rule = current_rule.next_rule
        end

        collected
      end
    end
  end
end


