#!/usr/bin/env ruby

require_relative 'lib/rule_engine'

puts "🚀 Rule Engine Test Runner"
puts "=" * 50

# Test 1: Basic Rule Engine Usage
puts "\n📋 Test 1: Basic Rule Engine Usage"
puts "-" * 30

# Create a simple rule set for testing
fraud_rules = RuleEngine::RuleSet.new(
  name: 'fraud_detection',
  rules: [
    RuleEngine::Rule.new(
      name: 'high_severity_fraud',
      priority: 100,
      condition: ->(context) { context.type == :fraud && context.severity >= 8 },
      outcomes: [
        ->(context) { RuleEngine::SuspendAccount.new(context, duration: 'indefinite', reason: 'High severity fraud') },
        ->(context) { RuleEngine::NotifySupport.new(context, priority: :high, message: 'High severity fraud detected') }
      ]
    ),
    RuleEngine::Rule.new(
      name: 'medium_severity_fraud',
      priority: 50,
      condition: ->(context) { context.type == :fraud && context.severity >= 5 && context.severity < 8 },
      outcomes: [
        ->(context) { RuleEngine::AddPenalty.new(context, points: 50, reason: 'Medium severity fraud') },
        ->(context) { RuleEngine::NotifySupport.new(context, priority: :medium, message: 'Medium severity fraud detected') }
      ]
    ),
    RuleEngine::Rule.new(
      name: 'low_severity_fraud',
      priority: 10,
      condition: ->(context) { context.type == :fraud && context.severity < 5 },
      outcomes: [
        ->(context) { RuleEngine::AddPenalty.new(context, points: 10, reason: 'Low severity fraud') }
      ]
    )
  ],
  strategy: :collect_all
)

# Create engine and register handlers
engine = RuleEngine::RuleEngine.new
engine.add_rule_set(fraud_rules)
engine.register_handlers(
  RuleEngine::PenaltyHandler.new,
  RuleEngine::AccountSuspensionHandler.new,
  RuleEngine::NotificationHandler.new,
  RuleEngine::LoggingHandler.new
)

# Test different violation scenarios
test_cases = [
  { name: "High Severity Fraud", type: :fraud, severity: 9, user_id: 123 },
  { name: "Medium Severity Fraud", type: :fraud, severity: 6, user_id: 124 },
  { name: "Low Severity Fraud", type: :fraud, severity: 3, user_id: 125 },
  { name: "Non-Fraud Violation", type: :spam, severity: 8, user_id: 126 }
]

test_cases.each do |test_case|
  puts "\n🔍 Testing: #{test_case[:name]}"
  
  context = RuleEngine::ViolationContext.new(
    type: test_case[:type],
    severity: test_case[:severity],
    user_id: test_case[:user_id],
    metadata: { test: true }
  )
  
  result = engine.evaluate_and_dispatch('fraud_detection', context)
  
  puts "   Outcomes: #{result[:outcomes].map(&:class).map(&:name).join(', ')}"
  puts "   Handlers executed: #{result[:dispatch_results].length}"
end

# Test 2: Different Evaluation Strategies
puts "\n📋 Test 2: Evaluation Strategies"
puts "-" * 30

strategy_rules = RuleEngine::RuleSet.new(
  name: 'strategy_test',
  rules: [
    RuleEngine::Rule.new(
      name: 'rule1',
      priority: 100,
      condition: ->(context) { context.severity >= 5 },
      outcomes: [->(context) { RuleEngine::AddPenalty.new(context, points: 10) }]
    ),
    RuleEngine::Rule.new(
      name: 'rule2',
      priority: 50,
      condition: ->(context) { context.severity >= 3 },
      outcomes: [->(context) { RuleEngine::LogViolation.new(context, level: :info) }]
    ),
    RuleEngine::Rule.new(
      name: 'rule3',
      priority: 10,
      condition: ->(context) { context.severity >= 1 },
      outcomes: [->(context) { RuleEngine::NotifyUser.new(context, message: 'Violation detected') }]
    )
  ]
)

engine.add_rule_set(strategy_rules)

context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)

puts "\n🔍 First Match Strategy:"
result = engine.evaluate('strategy_test', context, strategy: :first_match)
puts "   Outcomes: #{result.map(&:class).map(&:name).join(', ')}"

puts "\n🔍 Collect All Strategy:"
result = engine.evaluate('strategy_test', context, strategy: :collect_all)
puts "   Outcomes: #{result.map(&:class).map(&:name).join(', ')}"

# Test 3: Transaction Support
puts "\n📋 Test 3: Transaction Support"
puts "-" * 30

transaction_rules = RuleEngine::RuleSet.new(
  name: 'transaction_test',
  rules: [
    RuleEngine::Rule.new(
      name: 'transaction_rule',
      condition: ->(context) { context.severity >= 5 },
      outcomes: [
        ->(context) { RuleEngine::AddPenalty.new(context, points: 20) },
        ->(context) { RuleEngine::LogViolation.new(context, level: :warn) }
      ]
    )
  ]
)

engine.add_rule_set(transaction_rules)

context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
transaction_id = "txn_#{Time.now.to_i}"

puts "\n🔍 Transaction Execution:"
result = engine.evaluate('transaction_test', context, transaction_id: transaction_id)
puts "   Transaction ID: #{transaction_id}"
puts "   Outcomes: #{result.map(&:class).map(&:name).join(', ')}"
puts "   Active transactions: #{engine.transaction_manager.active_transaction_count}"

# Test 4: Rule Management
puts "\n📋 Test 4: Rule Management"
puts "-" * 30

manageable_rules = RuleEngine::RuleSet.new(
  name: 'manageable_test',
  rules: [
    RuleEngine::Rule.new(
      name: 'rule1',
      condition: ->(context) { context.severity >= 5 },
      outcomes: [->(context) { RuleEngine::AddPenalty.new(context, points: 10) }]
    ),
    RuleEngine::Rule.new(
      name: 'rule2',
      condition: ->(context) { context.severity >= 3 },
      outcomes: [->(context) { RuleEngine::LogViolation.new(context) }]
    )
  ]
)

engine.add_rule_set(manageable_rules)

context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)

puts "\n🔍 All Rules Enabled:"
result = engine.evaluate('manageable_test', context)
puts "   Outcomes: #{result.map(&:class).map(&:name).join(', ')}"

# Disable rule1
rule_set = engine.rule_set('manageable_test')
rule_set.disable_rule('rule1')

puts "\n🔍 After Disabling rule1:"
result = engine.evaluate('manageable_test', context)
puts "   Outcomes: #{result.map(&:class).map(&:name).join(', ')}"
puts "   Enabled rules: #{rule_set.enabled_rules.map(&:name).join(', ')}"
puts "   Disabled rules: #{rule_set.disabled_rules.map(&:name).join(', ')}"

# Test 5: DSL Usage
puts "\n📋 Test 5: DSL Usage"
puts "-" * 30

class TestProcessor
  include RuleEngine::DSL
  include RuleEngine::DSL::ConditionHelpers
end

processor = TestProcessor.new

dsl_rules = processor.define_rule_set("dsl_test") do
  rule "dsl_rule", priority: 50 do
    when { |context| context.severity >= 5 }
    add_penalty points: 25, reason: "DSL rule violation"
    log_violation level: :warn
  end
end

engine.add_rule_set(dsl_rules)

context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)

puts "\n🔍 DSL Rule Execution:"
result = engine.evaluate('dsl_test', context)
puts "   Outcomes: #{result.map(&:class).map(&:name).join(', ')}"

# Test 6: Engine Statistics
puts "\n📋 Test 6: Engine Statistics"
puts "-" * 30

stats = engine.stats
puts "   Rule sets: #{stats[:rule_sets_count]}"
puts "   Total rules: #{stats[:total_rules]}"
puts "   Enabled rules: #{stats[:enabled_rules]}"
puts "   Handlers: #{stats[:handlers_count]}"
puts "   Active transactions: #{stats[:active_transactions]}"

puts "\n✅ All tests completed successfully!"
puts "=" * 50

