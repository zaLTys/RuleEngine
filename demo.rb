#!/usr/bin/env ruby

require_relative 'lib/rule_engine'

puts "🎯 Rule Engine Comprehensive Demo"
puts "=" * 50

# Initialize the engine with all handlers
engine = RuleEngine::RuleEngine.new
engine.register_handlers(
  RuleEngine::PenaltyHandler.new,
  RuleEngine::AccountSuspensionHandler.new,
  RuleEngine::NotificationHandler.new,
  RuleEngine::LoggingHandler.new,
  RuleEngine::ActionBlockingHandler.new
)

puts "\n📋 Demo 1: Basic Fraud Detection Rules"
puts "-" * 40

# Create fraud detection rules
fraud_rules = RuleEngine::RuleSet.new(
  name: 'fraud_detection',
  rules: [
    RuleEngine::Rule.new(
      name: 'critical_fraud',
      priority: 100,
      condition: ->(context) { context.type == :fraud && context.severity >= 9 },
      outcomes: [
        ->(context) { RuleEngine::SuspendAccount.new(context, duration: 'indefinite', reason: 'Critical fraud') },
        ->(context) { RuleEngine::NotifySupport.new(context, priority: :high, message: 'Critical fraud detected') },
        ->(context) { RuleEngine::BlockAction.new(context, action_type: :login, reason: 'Account compromised') }
      ]
    ),
    RuleEngine::Rule.new(
      name: 'high_severity_fraud',
      priority: 80,
      condition: ->(context) { context.type == :fraud && context.severity >= 7 && context.severity < 9 },
      outcomes: [
        ->(context) { RuleEngine::SuspendAccount.new(context, duration: '30 days', reason: 'High severity fraud') },
        ->(context) { RuleEngine::AddPenalty.new(context, points: 100, reason: 'High severity fraud') },
        ->(context) { RuleEngine::NotifySupport.new(context, priority: :medium, message: 'High severity fraud detected') }
      ]
    ),
    RuleEngine::Rule.new(
      name: 'medium_severity_fraud',
      priority: 50,
      condition: ->(context) { context.type == :fraud && context.severity >= 5 && context.severity < 7 },
      outcomes: [
        ->(context) { RuleEngine::AddPenalty.new(context, points: 50, reason: 'Medium severity fraud') },
        ->(context) { RuleEngine::NotifyUser.new(context, message: 'Your account has been flagged for suspicious activity', channel: :email) }
      ]
    ),
    RuleEngine::Rule.new(
      name: 'low_severity_fraud',
      priority: 20,
      condition: ->(context) { context.type == :fraud && context.severity < 5 },
      outcomes: [
        ->(context) { RuleEngine::AddPenalty.new(context, points: 10, reason: 'Low severity fraud') },
        ->(context) { RuleEngine::LogViolation.new(context, level: :info, details: 'Minor fraud attempt logged') }
      ]
    )
  ],
  strategy: :collect_all
)

engine.add_rule_set(fraud_rules)

# Test different fraud scenarios
fraud_scenarios = [
  { name: "Critical Fraud (Severity 10)", type: :fraud, severity: 10, user_id: 1001 },
  { name: "High Severity Fraud (Severity 8)", type: :fraud, severity: 8, user_id: 1002 },
  { name: "Medium Severity Fraud (Severity 6)", type: :fraud, severity: 6, user_id: 1003 },
  { name: "Low Severity Fraud (Severity 3)", type: :fraud, severity: 3, user_id: 1004 },
  { name: "Non-Fraud Violation", type: :spam, severity: 8, user_id: 1005 }
]

fraud_scenarios.each do |scenario|
  puts "\n🔍 Testing: #{scenario[:name]}"
  
  context = RuleEngine::ViolationContext.new(
    type: scenario[:type],
    severity: scenario[:severity],
    user_id: scenario[:user_id],
    metadata: { source: 'demo', timestamp: Time.now }
  )
  
  result = engine.evaluate_and_dispatch('fraud_detection', context)
  
  puts "   Outcomes: #{result[:outcomes].map(&:class).map(&:name).join(', ')}"
  puts "   Handlers executed: #{result[:dispatch_results].length}"
end

puts "\n📋 Demo 2: Spam Detection with First-Match Strategy"
puts "-" * 40

# Create spam detection rules with first-match strategy
spam_rules = RuleEngine::RuleSet.new(
  name: 'spam_detection',
  rules: [
    RuleEngine::Rule.new(
      name: 'severe_spam',
      priority: 100,
      condition: ->(context) { context.type == :spam && context.severity >= 8 },
      outcomes: [
        ->(context) { RuleEngine::SuspendAccount.new(context, duration: '7 days', reason: 'Severe spam violation') },
        ->(context) { RuleEngine::NotifyUser.new(context, message: 'Your account has been suspended for 7 days due to spam violations', channel: :email) }
      ]
    ),
    RuleEngine::Rule.new(
      name: 'moderate_spam',
      priority: 50,
      condition: ->(context) { context.type == :spam && context.severity >= 5 },
      outcomes: [
        ->(context) { RuleEngine::AddPenalty.new(context, points: 25, reason: 'Moderate spam violation') },
        ->(context) { RuleEngine::NotifyUser.new(context, message: 'You have received a penalty for spam violations', channel: :email) }
      ]
    ),
    RuleEngine::Rule.new(
      name: 'minor_spam',
      priority: 10,
      condition: ->(context) { context.type == :spam && context.severity < 5 },
      outcomes: [
        ->(context) { RuleEngine::AddPenalty.new(context, points: 5, reason: 'Minor spam violation') }
      ]
    )
  ],
  strategy: :first_match
)

engine.add_rule_set(spam_rules)

# Test spam scenarios
spam_scenarios = [
  { name: "Severe Spam (Severity 9)", type: :spam, severity: 9, user_id: 2001 },
  { name: "Moderate Spam (Severity 6)", type: :spam, severity: 6, user_id: 2002 },
  { name: "Minor Spam (Severity 3)", type: :spam, severity: 3, user_id: 2003 }
]

spam_scenarios.each do |scenario|
  puts "\n🔍 Testing: #{scenario[:name]}"
  
  context = RuleEngine::ViolationContext.new(
    type: scenario[:type],
    severity: scenario[:severity],
    user_id: scenario[:user_id],
    metadata: { source: 'demo' }
  )
  
  result = engine.evaluate_and_dispatch('spam_detection', context)
  
  puts "   Outcomes: #{result[:outcomes].map(&:class).map(&:name).join(', ')}"
  puts "   Handlers executed: #{result[:dispatch_results].length}"
end

puts "\n📋 Demo 3: Rule Management"
puts "-" * 40

# Demonstrate rule management
rule_set = engine.rule_set('fraud_detection')

puts "Initial state:"
puts "   Total rules: #{rule_set.size}"
puts "   Enabled rules: #{rule_set.enabled_rules.size}"
puts "   Disabled rules: #{rule_set.disabled_rules.size}"

# Disable a rule
puts "\nDisabling 'low_severity_fraud' rule..."
rule_set.disable_rule('low_severity_fraud')

puts "After disabling:"
puts "   Enabled rules: #{rule_set.enabled_rules.map(&:name).join(', ')}"
puts "   Disabled rules: #{rule_set.disabled_rules.map(&:name).join(', ')}"

# Test with disabled rule
context = RuleEngine::ViolationContext.new(type: :fraud, severity: 3, user_id: 3001)
result = engine.evaluate('fraud_detection', context)
puts "   Low severity fraud with disabled rule: #{result.map(&:class).map(&:name).join(', ')}"

# Re-enable the rule
puts "\nRe-enabling 'low_severity_fraud' rule..."
rule_set.enable_rule('low_severity_fraud')

# Test again
result = engine.evaluate('fraud_detection', context)
puts "   Low severity fraud with re-enabled rule: #{result.map(&:class).map(&:name).join(', ')}"

puts "\n📋 Demo 4: Transaction Support"
puts "-" * 40

# Create transaction rules
transaction_rules = RuleEngine::RuleSet.new(
  name: 'transaction_test',
  rules: [
    RuleEngine::Rule.new(
      name: 'transaction_rule',
      condition: ->(context) { context.severity >= 5 },
      outcomes: [
        ->(context) { RuleEngine::AddPenalty.new(context, points: 20) },
        ->(context) { RuleEngine::LogViolation.new(context, level: :warn) },
        ->(context) { RuleEngine::NotifySupport.new(context, priority: :medium) }
      ]
    )
  ]
)

engine.add_rule_set(transaction_rules)

# Execute within transaction
context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 4001)
transaction_id = "txn_#{Time.now.to_i}"

puts "Executing rules within transaction: #{transaction_id}"
result = engine.evaluate('transaction_test', context, transaction_id: transaction_id)
puts "   Transaction outcomes: #{result.map(&:class).map(&:name).join(', ')}"
puts "   Active transactions: #{engine.transaction_manager.active_transaction_count}"

puts "\n📋 Demo 5: Engine Statistics"
puts "-" * 40

stats = engine.stats
puts "Engine Statistics:"
puts "   Rule sets: #{stats[:rule_sets_count]}"
puts "   Total rules: #{stats[:total_rules]}"
puts "   Enabled rules: #{stats[:enabled_rules]}"
puts "   Handlers: #{stats[:handlers_count]}"
puts "   Active transactions: #{stats[:active_transactions]}"

puts "\n📋 Demo 6: Custom Evaluation Strategies"
puts "-" * 40

# Test different strategies
context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 5001)

puts "First Match Strategy:"
result = engine.evaluate('fraud_detection', context, strategy: :first_match)
puts "   Outcomes: #{result.map(&:class).map(&:name).join(', ')}"

puts "\nCollect All Strategy:"
result = engine.evaluate('fraud_detection', context, strategy: :collect_all)
puts "   Outcomes: #{result.map(&:class).map(&:name).join(', ')}"

puts "\nStop on SuspendAccount Strategy:"
stop_strategy = RuleEngine::EvaluationStrategy::StopOnOutcome.new(RuleEngine::SuspendAccount)
result = stop_strategy.evaluate(engine.rule_set('fraud_detection'), context)
puts "   Outcomes: #{result.map(&:class).map(&:name).join(', ')}"

puts "\n✅ Demo completed successfully!"
puts "=" * 50

