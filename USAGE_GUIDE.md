# Rule Engine Usage Guide

This guide shows you how to use the Rule Engine application with various examples and scenarios.

## Quick Start

### 1. Basic Rule Engine Setup

```ruby
require 'rule_engine'

# Create an engine
engine = RuleEngine::RuleEngine.new

# Register action handlers
engine.register_handlers(
  RuleEngine::PenaltyHandler.new,
  RuleEngine::AccountSuspensionHandler.new,
  RuleEngine::NotificationHandler.new,
  RuleEngine::LoggingHandler.new
)
```

### 2. Creating Rules

```ruby
# Define a rule
rule = RuleEngine::Rule.new(
  name: 'high_severity_fraud',
  priority: 100,
  condition: ->(context) { context.type == :fraud && context.severity >= 8 },
  outcomes: [
    ->(context) { RuleEngine::SuspendAccount.new(context, duration: 'indefinite', reason: 'High severity fraud') },
    ->(context) { RuleEngine::NotifySupport.new(context, priority: :high, message: 'High severity fraud detected') }
  ]
)

# Create a rule set
rule_set = RuleEngine::RuleSet.new(
  name: 'fraud_detection',
  rules: [rule],
  strategy: :collect_all
)

# Add to engine
engine.add_rule_set(rule_set)
```

### 3. Evaluating Rules

```ruby
# Create a violation context
context = RuleEngine::ViolationContext.new(
  type: :fraud,
  severity: 9,
  user_id: 123,
  metadata: { source: 'automated_detection' }
)

# Evaluate rules
result = engine.evaluate_and_dispatch('fraud_detection', context)
puts "Outcomes: #{result[:outcomes].map(&:class).map(&:name)}"
```

## Advanced Usage

### 1. Using the DSL

```ruby
class ViolationProcessor
  include RuleEngine::DSL
  include RuleEngine::DSL::ConditionHelpers
end

processor = ViolationProcessor.new

# Define rules using DSL
fraud_rules = processor.define_rule_set("fraud_detection") do
  rule "high_severity_fraud", priority: 100 do
    when { |context| context.type == :fraud && context.severity >= 8 }
    suspend_account duration: "indefinite", reason: "High severity fraud"
    notify_support priority: :high, message: "High severity fraud detected"
  end

  rule "medium_severity_fraud", priority: 50 do
    when { |context| context.type == :fraud && context.severity >= 5 && context.severity < 8 }
    add_penalty points: 50, reason: "Medium severity fraud"
    notify_support priority: :medium
  end
end

engine.add_rule_set(fraud_rules)
```

### 2. Loading from Configuration

Create a YAML configuration file:

```yaml
# config/rules.yaml
fraud_detection:
  strategy: collect_all
  rules:
    - name: "high_severity_fraud"
      priority: 100
      condition:
        type: and
        conditions:
          - type: field_equals
            field: type
            value: fraud
          - type: field_greater_than
            field: severity
            value: 8
      outcomes:
        - type: suspend_account
          duration: "indefinite"
          reason: "High severity fraud"
        - type: notify_support
          priority: high
          message: "High severity fraud detected"
```

Load the configuration:

```ruby
engine.load_from_config('config/rules.yaml')
```

### 3. Different Evaluation Strategies

```ruby
# First match strategy (stops at first matching rule)
result = engine.evaluate('rule_set', context, strategy: :first_match)

# Collect all strategy (evaluates all matching rules)
result = engine.evaluate('rule_set', context, strategy: :collect_all)

# Custom strategy
stop_strategy = RuleEngine::EvaluationStrategy::StopOnOutcome.new(RuleEngine::SuspendAccount)
result = stop_strategy.evaluate(rule_set, context)
```

### 4. Transaction Support

```ruby
# Execute rules within a transaction
transaction_id = "txn_#{Time.now.to_i}"
result = engine.evaluate('rule_set', context, transaction_id: transaction_id)

# All outcomes within the transaction are collected and can be committed/rolled back together
```

### 5. Rule Management

```ruby
# Get rule set
rule_set = engine.rule_set('fraud_detection')

# Disable a rule
rule_set.disable_rule('high_severity_fraud')

# Enable a rule
rule_set.enable_rule('high_severity_fraud')

# Add a new rule
new_rule = RuleEngine::Rule.new(
  name: 'new_rule',
  condition: ->(context) { context.severity >= 10 },
  outcomes: [->(context) { RuleEngine::BlockAction.new(context, action_type: :login) }]
)
rule_set.add_rule(new_rule)

# Remove a rule
rule_set.remove_rule('old_rule')
```

### 6. Custom Action Handlers

```ruby
class CustomEmailHandler < RuleEngine::ActionHandler
  def can_handle?(outcome)
    outcome.is_a?(RuleEngine::NotifyUser) && outcome.channel == :email
  end

  def handle(outcome)
    # Send email logic here
    puts "Sending email: #{outcome.message}"
  end
end

engine.register_handlers(CustomEmailHandler.new)
```

### 7. Custom Outcomes

```ruby
class CustomOutcome < RuleEngine::Outcome
  attr_reader :action, :parameters

  def initialize(context, action:, parameters: {}, **options)
    super(context, **options)
    @action = action.to_sym
    @parameters = parameters.freeze
  end
end
```

## Testing

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/simple_spec.rb

# Run with documentation format
bundle exec rspec --format documentation
```

### Running Examples

```bash
# Run the simple test
ruby simple_test.rb

# Run the comprehensive examples
ruby examples/usage_examples.rb

# Run advanced examples
ruby examples/advanced_usage.rb
```

## Configuration Reference

### YAML Configuration Format

```yaml
rule_set_name:
  strategy: collect_all  # or first_match
  metadata:
    description: "Rule set description"
    version: "1.0"
  rules:
    - name: "rule_name"
      priority: 50
      enabled: true
      condition:
        type: and  # and, or, not, field_equals, field_greater_than, etc.
        conditions: [...]
      outcomes:
        - type: add_penalty  # add_penalty, suspend_account, notify_support, etc.
          points: 10
          reason: "Violation reason"
```

### Supported Condition Types

- `field_equals`: Check if field equals value
- `field_greater_than`: Check if field is greater than value
- `field_less_than`: Check if field is less than value
- `field_in`: Check if field value is in array
- `and`: All conditions must be true
- `or`: Any condition must be true
- `not`: Negate a condition
- `custom`: Execute custom Ruby code

### Supported Outcome Types

- `add_penalty`: Add penalty points
- `suspend_account`: Suspend user account
- `notify_support`: Send notification to support
- `notify_user`: Send notification to user
- `log_violation`: Log violation details
- `block_action`: Block specific user action
- `custom`: Execute custom outcome code

## Best Practices

1. **Keep Rules Simple**: Each rule should have a single responsibility
2. **Use Descriptive Names**: Name rules and rule sets clearly
3. **Set Appropriate Priorities**: Higher priority rules execute first
4. **Test Rules Independently**: Unit test individual rules
5. **Use Transactions**: For rules that need to be applied together
6. **Monitor Performance**: Log rule execution times for optimization
7. **Handle Errors Gracefully**: Rules should not break the entire evaluation process

## Troubleshooting

### Common Issues

1. **Rule not firing**: Check condition logic and rule priority
2. **Outcome not handled**: Ensure appropriate action handler is registered
3. **Performance issues**: Consider rule ordering and condition complexity
4. **Configuration errors**: Validate YAML/JSON syntax and field names

### Debugging

```ruby
# Enable debug logging
engine.logger.level = Logger::DEBUG

# Check rule set status
puts engine.stats

# Inspect rule conditions
rule_set.rules.each do |rule|
  puts "Rule: #{rule.name}, Enabled: #{rule.enabled?}, Priority: #{rule.priority}"
end
```

## Examples

See the `examples/` directory for comprehensive usage examples:

- `usage_examples.rb`: Basic usage patterns
- `advanced_usage.rb`: Advanced features and customizations
- `violation_rules.yaml`: Sample rule configurations
- `simple_test.rb`: Simple test runner

## API Reference

### Core Classes

- `RuleEngine::ViolationContext`: Input data for rule evaluation
- `RuleEngine::Rule`: Individual business rule
- `RuleEngine::RuleSet`: Collection of related rules
- `RuleEngine::RuleEngine`: Main orchestrator
- `RuleEngine::Outcome`: Results produced by rules
- `RuleEngine::ActionHandler`: Processes rule outcomes

### Key Methods

- `engine.evaluate(rule_set_name, context, options)`: Evaluate rules
- `engine.evaluate_and_dispatch(rule_set_name, context, options)`: Evaluate and dispatch outcomes
- `engine.add_rule_set(rule_set)`: Add a rule set
- `engine.register_handlers(*handlers)`: Register action handlers
- `rule_set.disable_rule(name)`: Disable a rule
- `rule_set.enable_rule(name)`: Enable a rule

