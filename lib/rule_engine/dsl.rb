module RuleEngine
  # Domain Specific Language for defining rules and rule sets
  module DSL
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Define a rule set with a block
      def define_rule_set(name, strategy: :collect_all, metadata: {}, &block)
        builder = RuleSetBuilder.new(name, strategy: strategy, metadata: metadata)
        builder.instance_eval(&block) if block_given?
        builder.build
      end

      # Define a single rule
      def define_rule(name, priority: 0, enabled: true, metadata: {}, &block)
        builder = RuleBuilder.new(name, priority: priority, enabled: enabled, metadata: metadata)
        builder.instance_eval(&block) if block_given?
        builder.build
      end
    end

    # Builder for creating rule sets
    class RuleSetBuilder
      attr_reader :name, :strategy, :metadata, :rules

      def initialize(name, strategy: :collect_all, metadata: {})
        @name = name
        @strategy = strategy
        @metadata = metadata
        @rules = []
      end

      def rule(name, priority: 0, enabled: true, metadata: {}, &block)
        rule_builder = RuleBuilder.new(name, priority: priority, enabled: enabled, metadata: metadata)
        rule_builder.instance_eval(&block) if block_given?
        @rules << rule_builder.build
      end

      def build
        RuleSet.new(
          name: @name,
          rules: @rules,
          strategy: @strategy,
          metadata: @metadata
        )
      end
    end

    # Builder for creating individual rules
    class RuleBuilder
      attr_reader :name, :priority, :enabled, :metadata, :condition, :outcomes

      def initialize(name, priority: 0, enabled: true, metadata: {})
        @name = name
        @priority = priority
        @enabled = enabled
        @metadata = metadata
        @condition = nil
        @outcomes = []
      end

      def when_condition(&block)
        @condition = block
      end
      
      def when(&block)
        @condition = block
      end

      def condition(&block)
        @condition = block
      end

      def then(&block)
        @outcomes << block
      end

      def add_penalty(points:, reason: nil)
        @outcomes << ->(context) { AddPenalty.new(context, points: points, reason: reason) }
      end

      def suspend_account(duration: nil, reason: nil)
        @outcomes << ->(context) { SuspendAccount.new(context, duration: duration, reason: reason) }
      end

      def notify_support(priority: :medium, message: nil)
        @outcomes << ->(context) { NotifySupport.new(context, priority: priority, message: message) }
      end

      def notify_user(message:, channel: :email)
        @outcomes << ->(context) { NotifyUser.new(context, message: message, channel: channel) }
      end

      def log_violation(level: :info, details: nil)
        @outcomes << ->(context) { LogViolation.new(context, level: level, details: details) }
      end

      def block_action(action_type:, reason: nil)
        @outcomes << ->(context) { BlockAction.new(context, action_type: action_type, reason: reason) }
      end

      def custom_outcome(&block)
        @outcomes << block
      end

      def build
        raise ArgumentError, "Rule '#{@name}' must have a condition" unless @condition
        raise ArgumentError, "Rule '#{@name}' must have at least one outcome" if @outcomes.empty?

        Rule.new(
          name: @name,
          priority: @priority,
          condition: @condition,
          outcomes: @outcomes,
          enabled: @enabled,
          metadata: @metadata
        )
      end
    end

    # Helper methods for common conditions
    module ConditionHelpers
      def severity_at_least(level)
        ->(context) { context.severity >= level }
      end

      def severity_between(min, max)
        ->(context) { context.severity >= min && context.severity <= max }
      end

      def violation_type(type)
        ->(context) { context.type == type.to_sym }
      end

      def violation_types(*types)
        types = types.map(&:to_sym)
        ->(context) { types.include?(context.type) }
      end

      def user_id_equals(user_id)
        ->(context) { context.user_id == user_id }
      end

      def metadata_contains(key, value)
        ->(context) { context.metadata[key.to_s] == value }
      end

      def metadata_has_key(key)
        ->(context) { context.metadata.key?(key.to_s) }
      end

      def all_of(*conditions)
        ->(context) { conditions.all? { |condition| condition.call(context) } }
      end

      def any_of(*conditions)
        ->(context) { conditions.any? { |condition| condition.call(context) } }
      end

      def not(condition)
        ->(context) { !condition.call(context) }
      end
    end
  end
end

