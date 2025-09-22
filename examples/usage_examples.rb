#!/usr/bin/env ruby

require_relative '../lib/rule_engine'
require 'json'

# Example 1: Basic usage with DSL
puts "=== Example 1: Basic DSL Usage ==="

# Include DSL module
class ViolationProcessor
  include RuleEngine::DSL
  include RuleEngine::DSL::ConditionHelpers
end

processor = ViolationProcessor.new

# Define a rule set using DSL
fraud_rules = processor.define_rule_set("fraud_detection", strategy: :collect_all) do
  rule "high_severity_fraud", priority: 100 do
    when { |context| context.type == :fraud && context.severity >= 8 }
    then do |context|
      [
        RuleEngine::SuspendAccount.new(context, duration: "indefinite", reason: "High severity fraud"),
        RuleEngine::NotifySupport.new(context, priority: :high, message: "High severity fraud detected")
      ]
    end
  end

  rule "medium_severity_fraud", priority: 50 do
    when { |context| context.type == :fraud && context.severity >= 5 && context.severity < 8 }
    add_penalty points: 50, reason: "Medium severity fraud"
    notify_support priority: :medium, message: "Medium severity fraud detected"
  end

  rule "low_severity_fraud", priority: 10 do
    when { |context| context.type == :fraud && context.severity < 5 }
    add_penalty points: 10, reason: "Low severity fraud"
    log_violation level: :info
  end
end

# Create engine and add rule set
engine = RuleEngine::RuleEngine.new
engine.add_rule_set(fraud_rules)

# Register action handlers
engine.register_handlers(
  RuleEngine::PenaltyHandler.new,
  RuleEngine::AccountSuspensionHandler.new,
  RuleEngine::NotificationHandler.new,
  RuleEngine::LoggingHandler.new
)

# Test with different violation contexts
puts "\nTesting fraud violations:"

# High severity fraud
high_fraud = RuleEngine::ViolationContext.new(
  type: :fraud,
  severity: 9,
  user_id: 123,
  metadata: { source: "automated_detection" }
)

result = engine.evaluate_and_dispatch("fraud_detection", high_fraud)
puts "High fraud result: #{result[:outcomes].map(&:class).map(&:name)}"

# Medium severity fraud
medium_fraud = RuleEngine::ViolationContext.new(
  type: :fraud,
  severity: 6,
  user_id: 124,
  metadata: { source: "user_report" }
)

result = engine.evaluate_and_dispatch("fraud_detection", medium_fraud)
puts "Medium fraud result: #{result[:outcomes].map(&:class).map(&:name)}"

# Example 2: Loading from configuration file
puts "\n=== Example 2: Configuration File Usage ==="

# Load rules from YAML file
engine.load_from_config("examples/violation_rules.yaml")

# Test spam detection
spam_violation = RuleEngine::ViolationContext.new(
  type: :spam,
  severity: 8,
  user_id: 125,
  metadata: { content: "repeated_promotional_messages" }
)

result = engine.evaluate_and_dispatch("spam_detection", spam_violation)
puts "Spam detection result: #{result[:outcomes].map(&:class).map(&:name)}"

# Example 3: Transaction support
puts "\n=== Example 3: Transaction Support ==="

transaction_id = "txn_#{Time.now.to_i}"

# Execute rules within a transaction
result = engine.evaluate("fraud_detection", high_fraud, transaction_id: transaction_id)
puts "Transaction outcomes: #{result.map(&:class).map(&:name)}"

# Example 4: Custom evaluation strategies
puts "\n=== Example 4: Custom Evaluation Strategies ==="

# Use first match strategy
result = engine.evaluate("spam_detection", spam_violation, strategy: :first_match)
puts "First match result: #{result.map(&:class).map(&:name)}"

# Use stop on specific outcome strategy
stop_on_suspend = RuleEngine::EvaluationStrategy::StopOnOutcome.new(RuleEngine::SuspendAccount)
result = stop_on_suspend.evaluate(engine.rule_set("fraud_detection"), high_fraud)
puts "Stop on suspend result: #{result.map(&:class).map(&:name)}"

# Example 5: Rule management
puts "\n=== Example 5: Rule Management ==="

# Get engine statistics
puts "Engine stats: #{engine.stats}"

# Disable a rule
rule_set = engine.rule_set("fraud_detection")
rule_set.disable_rule("low_severity_fraud")
puts "Disabled low severity fraud rule"

# Test with disabled rule
low_fraud = RuleEngine::ViolationContext.new(
  type: :fraud,
  severity: 3,
  user_id: 126
)

result = engine.evaluate("fraud_detection", low_fraud)
puts "Low fraud with disabled rule: #{result.map(&:class).map(&:name)}"

# Re-enable the rule
rule_set.enable_rule("low_severity_fraud")
puts "Re-enabled low severity fraud rule"

# Example 6: Complex conditions
puts "\n=== Example 6: Complex Conditions ==="

# Create a rule with complex conditions using helper methods
complex_rule = processor.define_rule("complex_abuse_rule", priority: 75) do
  when do |context|
    all_of(
      violation_types(:harassment, :inappropriate_content),
      severity_at_least(5),
      metadata_contains("reported_by", "moderator")
    ).call(context)
  end
  
  suspend_account duration: "14 days", reason: "Complex abuse violation"
  notify_support priority: :high, message: "Complex abuse pattern detected"
  log_violation level: :error, details: "Multiple violation types detected"
end

# Add to a new rule set
abuse_rules = RuleEngine::RuleSet.new(name: "complex_abuse", rules: [complex_rule])
engine.add_rule_set(abuse_rules)

# Test complex condition
complex_violation = RuleEngine::ViolationContext.new(
  type: :harassment,
  severity: 6,
  user_id: 127,
  metadata: { reported_by: "moderator", pattern: "repeated_offenses" }
)

result = engine.evaluate("complex_abuse", complex_violation)
puts "Complex abuse result: #{result.map(&:class).map(&:name)}"

puts "\n=== All examples completed successfully! ==="


