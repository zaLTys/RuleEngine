module RuleEngine
  # Collection of rules configured for a particular domain or violation type
  class RuleSet
    attr_reader :name, :rules, :strategy, :metadata

    def initialize(name:, rules: [], strategy: :collect_all, metadata: {})
      @name = name.to_s
      @rules = rules.is_a?(Array) ? rules : [rules]
      @strategy = strategy.to_sym
      @metadata = metadata.freeze
    end

    def add_rule(rule)
      @rules << rule
      self
    end

    def remove_rule(rule_name)
      @rules.reject! { |rule| rule.name == rule_name.to_s }
      self
    end

    def find_rule(rule_name)
      @rules.find { |rule| rule.name == rule_name.to_s }
    end

    def enabled_rules
      @rules.select(&:enabled?)
    end

    def disabled_rules
      @rules.select(&:disabled?)
    end

    def enable_rule(rule_name)
      rule = find_rule(rule_name)
      rule&.enable!
      rule
    end

    def disable_rule(rule_name)
      rule = find_rule(rule_name)
      rule&.disable!
      rule
    end

    def enable_all!
      @rules.each(&:enable!)
      self
    end

    def disable_all!
      @rules.each(&:disable!)
      self
    end

    # Build a chain-of-responsibility based on priority
    def to_chain
      sorted_rules = enabled_rules.sort_by { |rule| -rule.priority }
      return nil if sorted_rules.empty?

      # Link rules in chain
      sorted_rules.each_cons(2) { |current, next_rule| current.next_rule = next_rule }
      sorted_rules.first
    end

    def evaluate(context)
      chain = to_chain
      return [] unless chain

      chain.evaluate(context, strategy: @strategy, collected: [])
    end

    def size
      @rules.size
    end

    def empty?
      @rules.empty?
    end

    def to_h
      {
        name: @name,
        strategy: @strategy,
        rules_count: @rules.size,
        enabled_rules_count: enabled_rules.size,
        metadata: @metadata
      }
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @name=#{@name} @rules_count=#{@rules.size} @strategy=#{@strategy}>"
    end
  end
end


