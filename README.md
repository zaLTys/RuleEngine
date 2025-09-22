# Rule Engine

A flexible, extensible rule engine for Ruby applications that allows you to create, chain, and manage business rules with support for transactions, multiple evaluation strategies, and comprehensive action handling.

## Features

- **Flexible Rule Definition**: Define rules using Ruby DSL or configuration files (YAML/JSON)
- **Rule Chaining**: Chain rules together using the Chain of Responsibility pattern
- **Multiple Evaluation Strategies**: Support for first-match, collect-all, and custom strategies
- **Transaction Support**: Execute rules within transaction scopes for data consistency
- **Action Handlers**: Decoupled action execution with built-in and custom handlers
- **Event Dispatching**: Observer pattern for handling rule outcomes
- **Comprehensive Logging**: Built-in audit trail and logging capabilities
- **Configuration Management**: Load rules from external configuration files
- **Extensible Architecture**: Easy to extend with custom rules, outcomes, and handlers

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rule_engine'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install rule_engine
```

## Quick Start

### Basic Usage

```ruby
require 'rule_engine'

# Create a violation context
context = RuleEngine::ViolationContext.new(
  type: :fraud,
  severity: 8,
  user_id: 123,
  metadata: { source: 'automated_detection' }
)

# Define a rule
rule = RuleEngine::Rule.new(
  name: 'high_severity_fraud',
  priority: 100,
  condition: ->(context) { context.severity >= 8 },
  outcomes: [
    ->(context) { RuleEngine::SuspendAccount.new(context, duration: 'indefinite') },
    ->(context) { RuleEngine::NotifySupport.new(context, priority: :high) }
  ]
)

# Create a rule set
rule_set = RuleEngine::RuleSet.new(
  name: 'fraud_detection',
  rules: [rule],
  strategy: :collect_all
)

# Create the engine
engine = RuleEngine::RuleEngine.new(rule_sets: { 'fraud_detection' => rule_set })

# Register action handlers
engine.register_handlers(
  RuleEngine::AccountSuspensionHandler.new,
  RuleEngine::NotificationHandler.new
)

# Evaluate rules
result = engine.evaluate_and_dispatch('fraud_detection', context)
puts result[:outcomes].map(&:class).map(&:name)
# => ["SuspendAccount", "NotifySupport"]
```

### Using the DSL

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

# Use with engine
engine = RuleEngine::RuleEngine.new
engine.add_rule_set(fraud_rules)
```

### Configuration File

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
engine = RuleEngine::RuleEngine.new
engine.load_from_config('config/rules.yaml')
```

## Architecture

### Core Components

- **ViolationContext**: Input data for rule evaluation
- **Rule**: Individual business rule with condition and outcomes
- **RuleSet**: Collection of related rules
- **RuleEngine**: Main orchestrator for rule evaluation
- **Outcome**: Results produced by rules
- **ActionHandler**: Processes rule outcomes
- **EventDispatcher**: Manages outcome distribution
- **TransactionManager**: Handles transactional rule execution

### Design Patterns

- **Rules Engine Pattern**: Core pattern for business rule evaluation
- **Chain of Responsibility**: For rule chaining and evaluation order
- **Strategy Pattern**: For different evaluation strategies
- **Observer Pattern**: For event dispatching
- **Command Pattern**: For action execution
- **Builder Pattern**: For DSL rule construction

## Advanced Usage

### Custom Evaluation Strategies

```ruby
# Stop on first matching rule
result = engine.evaluate('rule_set', context, strategy: :first_match)

# Stop when specific outcome is produced
stop_strategy = RuleEngine::EvaluationStrategy::StopOnOutcome.new(RuleEngine::SuspendAccount)
result = stop_strategy.evaluate(rule_set, context)

# Limit number of outcomes
limit_strategy = RuleEngine::EvaluationStrategy::LimitOutcomes.new(3)
result = limit_strategy.evaluate(rule_set, context)
```

### Transaction Support

```ruby
# Execute rules within a transaction
transaction_id = "txn_#{Time.now.to_i}"
result = engine.evaluate('rule_set', context, transaction_id: transaction_id)

# All outcomes within the transaction are collected and can be committed/rolled back together
```

### Custom Action Handlers

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

### Custom Outcomes

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

## Configuration

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

## Testing

Run the test suite:

```bash
bundle exec rspec
```

## Examples

See the `examples/` directory for comprehensive usage examples:

- `usage_examples.rb`: Basic usage patterns
- `advanced_usage.rb`: Advanced features and customizations
- `violation_rules.yaml`: Sample rule configurations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for your changes
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

### Version 1.0.0

- Initial release
- Core rule engine functionality
- DSL for rule definition
- Configuration file support
- Transaction management
- Action handlers and event dispatching
- Comprehensive test suite


