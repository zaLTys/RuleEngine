#!/usr/bin/env ruby

require_relative '../lib/rule_engine'

# Advanced usage examples demonstrating the flexibility of the rule engine

puts "=== Advanced Rule Engine Usage Examples ==="

# Example 1: Custom Action Handler
class CustomEmailHandler < RuleEngine::ActionHandler
  def initialize(name: 'CustomEmailHandler', **options)
    super(name: name, **options)
  end

  def can_handle?(outcome)
    outcome.is_a?(RuleEngine::NotifyUser) && outcome.channel == :email
  end

  def handle(outcome)
    return unless can_handle?(outcome) && enabled?

    # Simulate email sending
    puts "📧 Sending email to user #{outcome.context.user_id}: #{outcome.message}"
    
    # In a real application, you would:
    # - Look up user's email address
    # - Send actual email via SMTP/API
    # - Log the email send attempt
    # - Handle delivery failures
  end
end

# Example 2: Custom Outcome
class CustomOutcome < RuleEngine::Outcome
  attr_reader :action, :parameters

  def initialize(context, action:, parameters: {}, **options)
    super(context, **options)
    @action = action.to_sym
    @parameters = parameters.freeze
  end

  def to_h
    super.merge(action: @action, parameters: @parameters)
  end
end

# Example 3: Dynamic Rule Creation
class DynamicRuleBuilder
  include RuleEngine::DSL::ConditionHelpers

  def self.build_severity_based_rules(base_name, severity_thresholds)
    rules = []
    
    severity_thresholds.each_with_index do |(threshold, config), index|
      rule_name = "#{base_name}_severity_#{threshold}"
      
      condition = if index == 0
                    severity_at_least(threshold)
                  else
                    severity_between(severity_thresholds[index - 1][0], threshold)
                  end
      
      outcomes = config[:outcomes].map do |outcome_config|
        case outcome_config[:type]
        when :penalty
          ->(context) { RuleEngine::AddPenalty.new(context, points: outcome_config[:points]) }
        when :suspend
          ->(context) { RuleEngine::SuspendAccount.new(context, duration: outcome_config[:duration]) }
        when :notify
          ->(context) { RuleEngine::NotifyUser.new(context, message: outcome_config[:message]) }
        end
      end
      
      rules << RuleEngine::Rule.new(
        name: rule_name,
        priority: config[:priority],
        condition: condition,
        outcomes: outcomes
      )
    end
    
    rules
  end
end

# Example 4: Rule Engine with Custom Logger
class CustomLogger < Logger
  def initialize
    super(STDOUT)
    self.level = Logger::DEBUG
    self.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%H:%M:%S')}] #{severity}: #{msg}\n"
    end
  end
end

# Example 5: Performance Monitoring
class PerformanceMonitor
  def self.measure_execution_time(description, &block)
    start_time = Time.current
    result = yield
    end_time = Time.current
    execution_time = (end_time - start_time) * 1000 # Convert to milliseconds
    
    puts "⏱️  #{description}: #{execution_time.round(2)}ms"
    result
  end
end

# Example 6: Rule Validation
class RuleValidator
  def self.validate_rule(rule)
    errors = []
    
    # Check if rule has a condition
    errors << "Rule must have a condition" unless rule.instance_variable_get(:@condition)
    
    # Check if rule has outcomes
    outcomes = rule.instance_variable_get(:@outcomes)
    errors << "Rule must have at least one outcome" if outcomes.nil? || outcomes.empty?
    
    # Check if condition is callable
    condition = rule.instance_variable_get(:@condition)
    if condition && !condition.respond_to?(:call)
      errors << "Rule condition must be callable"
    end
    
    errors
  end
  
  def self.validate_rule_set(rule_set)
    errors = []
    
    # Check if rule set has rules
    errors << "Rule set must have at least one rule" if rule_set.empty?
    
    # Validate each rule
    rule_set.rules.each do |rule|
      rule_errors = validate_rule(rule)
      rule_errors.each { |error| errors << "Rule '#{rule.name}': #{error}" }
    end
    
    # Check for duplicate rule names
    rule_names = rule_set.rules.map(&:name)
    duplicates = rule_names.select { |name| rule_names.count(name) > 1 }.uniq
    duplicates.each { |name| errors << "Duplicate rule name: #{name}" }
    
    errors
  end
end

# Example 7: Rule Engine Factory
class RuleEngineFactory
  def self.create_standard_engine(config_path: nil)
    engine = RuleEngine::RuleEngine.new
    
    # Register standard handlers
    engine.register_handlers(
      RuleEngine::PenaltyHandler.new,
      RuleEngine::AccountSuspensionHandler.new,
      RuleEngine::NotificationHandler.new,
      RuleEngine::LoggingHandler.new,
      CustomEmailHandler.new
    )
    
    # Load configuration if provided
    engine.load_from_config(config_path) if config_path && File.exist?(config_path)
    
    engine
  end
  
  def self.create_high_performance_engine
    # Create engine optimized for high performance
    engine = RuleEngine::RuleEngine.new(logger: CustomLogger.new)
    
    # Register only essential handlers
    engine.register_handlers(
      RuleEngine::LoggingHandler.new(name: 'FastLogger')
    )
    
    engine
  end
end

# Example 8: Rule Testing Framework
class RuleTester
  def self.test_rule(rule, test_cases)
    results = []
    
    test_cases.each do |test_case|
      context = RuleEngine::ViolationContext.new(test_case[:context])
      expected_outcomes = test_case[:expected_outcomes] || []
      
      # Evaluate rule
      outcomes = rule.evaluate(context, strategy: :collect_all, collected: [])
      
      # Check if outcomes match expectations
      outcome_types = outcomes.map(&:class)
      expected_types = expected_outcomes.map { |type| Object.const_get(type) }
      
      passed = outcome_types == expected_types
      
      results << {
        test_case: test_case[:name],
        context: context,
        expected: expected_types,
        actual: outcome_types,
        passed: passed
      }
    end
    
    results
  end
end

# Example 9: Usage of all advanced features
puts "\n=== Running Advanced Examples ==="

# Create dynamic rules
severity_thresholds = [
  [5, { priority: 50, outcomes: [{ type: :penalty, points: 10 }] }],
  [8, { priority: 80, outcomes: [{ type: :suspend, duration: "7 days" }] }],
  [10, { priority: 100, outcomes: [{ type: :notify, message: "Account suspended" }] }]
]

dynamic_rules = DynamicRuleBuilder.build_severity_based_rules("dynamic_violation", severity_thresholds)
dynamic_rule_set = RuleEngine::RuleSet.new(name: "dynamic_rules", rules: dynamic_rules)

# Create engine with custom logger
engine = RuleEngineFactory.create_standard_engine(config_path: "examples/violation_rules.yaml")
engine.add_rule_set(dynamic_rule_set)

# Validate rule set
validation_errors = RuleValidator.validate_rule_set(dynamic_rule_set)
if validation_errors.any?
  puts "❌ Validation errors: #{validation_errors}"
else
  puts "✅ Rule set validation passed"
end

# Test with performance monitoring
test_context = RuleEngine::ViolationContext.new(
  type: :fraud,
  severity: 7,
  user_id: 999,
  metadata: { test: true }
)

PerformanceMonitor.measure_execution_time("Rule evaluation") do
  result = engine.evaluate_and_dispatch("dynamic_rules", test_context)
  puts "Dynamic rule result: #{result[:outcomes].map(&:class).map(&:name)}"
end

# Test rule with test framework
test_cases = [
  {
    name: "Low severity test",
    context: { type: :fraud, severity: 3, user_id: 1 },
    expected_outcomes: []
  },
  {
    name: "Medium severity test", 
    context: { type: :fraud, severity: 6, user_id: 2 },
    expected_outcomes: ["RuleEngine::AddPenalty"]
  },
  {
    name: "High severity test",
    context: { type: :fraud, severity: 9, user_id: 3 },
    expected_outcomes: ["RuleEngine::SuspendAccount", "RuleEngine::NotifyUser"]
  }
]

# Test the first dynamic rule
first_rule = dynamic_rules.first
test_results = RuleTester.test_rule(first_rule, test_cases)

puts "\n=== Rule Testing Results ==="
test_results.each do |result|
  status = result[:passed] ? "✅ PASS" : "❌ FAIL"
  puts "#{status} #{result[:test_case]}: Expected #{result[:expected]}, Got #{result[:actual]}"
end

puts "\n=== Advanced examples completed! ==="


