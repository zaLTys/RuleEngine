module RuleEngine
  # Loads rule configurations from YAML or JSON files
  class ConfigurationLoader
    def load_from_file(file_path)
      file_path = File.expand_path(file_path)
      raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)

      content = File.read(file_path)
      extension = File.extname(file_path).downcase

      case extension
      when '.yaml', '.yml'
        load_from_yaml(content)
      when '.json'
        load_from_json(content)
      else
        raise ArgumentError, "Unsupported file format: #{extension}. Supported formats: .yaml, .yml, .json"
      end
    end

    def load_from_yaml(content)
      require 'yaml'
      data = YAML.safe_load(content, permitted_classes: [Symbol])
      load_from_hash(data)
    end

    def load_from_json(content)
      require 'json'
      data = JSON.parse(content)
      load_from_hash(data)
    end

    def load_from_hash(data)
      rule_sets = []

      data.each do |rule_set_name, rule_set_config|
        rules = build_rules(rule_set_config['rules'] || [])
        
        rule_set = RuleSet.new(
          name: rule_set_name,
          rules: rules,
          strategy: rule_set_config['strategy'] || :collect_all,
          metadata: rule_set_config['metadata'] || {}
        )

        rule_sets << rule_set
      end

      rule_sets
    end

    private

    def build_rules(rules_config)
      rules_config.map do |rule_config|
        build_rule(rule_config)
      end
    end

    def build_rule(rule_config)
      name = rule_config['name']
      priority = rule_config['priority'] || 0
      enabled = rule_config.fetch('enabled', true)
      metadata = rule_config['metadata'] || {}

      # Build condition
      condition = build_condition(rule_config['condition'])

      # Build outcomes
      outcomes = build_outcomes(rule_config['outcomes'] || [])

      Rule.new(
        name: name,
        priority: priority,
        condition: condition,
        outcomes: outcomes,
        enabled: enabled,
        metadata: metadata
      )
    end

    def build_condition(condition_config)
      case condition_config
      when String
        # Simple expression evaluation (be careful with eval in production)
        ->(context) { eval(condition_config) }
      when Hash
        build_complex_condition(condition_config)
      when Proc
        condition_config
      else
        raise ArgumentError, "Invalid condition configuration: #{condition_config}"
      end
    end

    def build_complex_condition(condition_config)
      case condition_config['type']
      when 'and'
        conditions = condition_config['conditions'].map { |c| build_condition(c) }
        ->(context) { conditions.all? { |c| c.call(context) } }
      when 'or'
        conditions = condition_config['conditions'].map { |c| build_condition(c) }
        ->(context) { conditions.any? { |c| c.call(context) } }
      when 'not'
        condition = build_condition(condition_config['condition'])
        ->(context) { !condition.call(context) }
      when 'field_equals'
        field = condition_config['field']
        value = condition_config['value']
        ->(context) { context.send(field) == value }
      when 'field_greater_than'
        field = condition_config['field']
        value = condition_config['value']
        ->(context) { context.send(field) > value }
      when 'field_less_than'
        field = condition_config['field']
        value = condition_config['value']
        ->(context) { context.send(field) < value }
      when 'field_in'
        field = condition_config['field']
        values = condition_config['values']
        ->(context) { values.include?(context.send(field)) }
      when 'custom'
        # Custom Ruby code (use with caution)
        eval(condition_config['code'])
      else
        raise ArgumentError, "Unknown condition type: #{condition_config['type']}"
      end
    end

    def build_outcomes(outcomes_config)
      outcomes_config.map do |outcome_config|
        build_outcome(outcome_config)
      end
    end

    def build_outcome(outcome_config)
      case outcome_config['type']
      when 'add_penalty'
        ->(context) { AddPenalty.new(context, points: outcome_config['points'], reason: outcome_config['reason']) }
      when 'suspend_account'
        ->(context) { SuspendAccount.new(context, duration: outcome_config['duration'], reason: outcome_config['reason']) }
      when 'notify_support'
        ->(context) { NotifySupport.new(context, priority: outcome_config['priority'], message: outcome_config['message']) }
      when 'notify_user'
        ->(context) { NotifyUser.new(context, message: outcome_config['message'], channel: outcome_config['channel']) }
      when 'log_violation'
        ->(context) { LogViolation.new(context, level: outcome_config['level'], details: outcome_config['details']) }
      when 'block_action'
        ->(context) { BlockAction.new(context, action_type: outcome_config['action_type'], reason: outcome_config['reason']) }
      when 'custom'
        # Custom outcome creation
        ->(context) { eval(outcome_config['code']) }
      else
        raise ArgumentError, "Unknown outcome type: #{outcome_config['type']}"
      end
    end
  end
end


