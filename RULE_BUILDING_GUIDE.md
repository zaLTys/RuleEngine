# Complete Rule Building Guide

This guide provides comprehensive examples of how to build rules using the Rule Engine, from basic concepts to advanced patterns.

## Table of Contents
1. [Basic Rule Concepts](#basic-rule-concepts)
2. [Rule Building Methods](#rule-building-methods)
3. [DSL Usage Examples](#dsl-usage-examples)
4. [Configuration-Based Rules](#configuration-based-rules)
5. [Advanced Rule Patterns](#advanced-rule-patterns)
6. [Rails API Integration](#rails-api-integration)
7. [Best Practices](#best-practices)

## Basic Rule Concepts

### Rule Components

Every rule consists of:
- **Name**: Unique identifier for the rule
- **Condition**: Lambda function that evaluates context
- **Outcomes**: Actions to execute when condition is true
- **Priority**: Execution order (higher numbers = higher priority)
- **Metadata**: Additional information about the rule

### Violation Context

Rules evaluate against a `ViolationContext` containing:
```ruby
context = RuleEngine::ViolationContext.new(
  type: :fraud,           # Type of violation
  severity: 8,            # Severity level (1-10)
  user_id: 123,          # User identifier
  metadata: {            # Additional context data
    'source' => 'automated',
    'confidence' => 0.95
  }
)
```

## Rule Building Methods

### 1. Direct Rule Creation

```ruby
# Create a rule directly
rule = RuleEngine::Rule.new(
  name: 'high_fraud_detection',
  priority: 100,
  condition: ->(context) { 
    context.type == :fraud && context.severity >= 8 
  },
  outcomes: [
    ->(context) { 
      RuleEngine::SuspendAccount.new(context, 
        duration: 'indefinite', 
        reason: 'High severity fraud detected'
      ) 
    },
    ->(context) { 
      RuleEngine::NotifySupport.new(context, 
        priority: :high, 
        message: 'Immediate attention required'
      ) 
    }
  ]
)

# Add to rule set
rule_set = RuleEngine::RuleSet.new(
  name: 'fraud_detection',
  rules: [rule],
  strategy: :collect_all
)
```

### 2. Using the DSL (Recommended)

```ruby
class RuleBuilder
  include RuleEngine::DSL
  include RuleEngine::DSL::ConditionHelpers
end

builder = RuleBuilder.new

# Define rules using DSL
fraud_rules = builder.define_rule_set('fraud_detection') do
  rule 'critical_fraud', priority: 100 do
    when { |ctx| ctx.type == :fraud && ctx.severity >= 9 }
    suspend_account duration: 'indefinite', reason: 'Critical fraud'
    add_penalty points: 100, reason: 'Critical fraud violation'
    notify_support priority: :critical, message: 'Critical fraud detected'
  end
  
  rule 'high_fraud', priority: 80 do
    when { |ctx| ctx.type == :fraud && ctx.severity >= 7 }
    suspend_account duration: '30', reason: 'High fraud'
    add_penalty points: 75, reason: 'High fraud violation'
    notify_support priority: :high, message: 'High fraud detected'
  end
end
```

## DSL Usage Examples

### Basic Rule Structure

```ruby
rule 'rule_name', priority: 50 do
  # Condition - when should this rule fire?
  when { |context| condition_logic }
  
  # Outcomes - what should happen?
  add_penalty points: 25, reason: 'Violation detected'
  notify_user message: 'Warning message', channel: :email
  log_violation level: :warn, details: 'Rule triggered'
end
```

### Using Condition Helpers

```ruby
# Include helper methods
include RuleEngine::DSL::ConditionHelpers

rule 'severity_based_rule', priority: 60 do
  when do |context|
    all_of(
      violation_type(:fraud),
      severity_at_least(7),
      metadata_contains('source', 'automated')
    ).call(context)
  end
  
  suspend_account duration: '14', reason: 'Automated fraud detection'
end
```

### Complex Conditions

```ruby
rule 'repeat_offender_escalation', priority: 90 do
  when do |context|
    # Multiple conditions with complex logic
    user_violations = context.metadata['total_violations'].to_i
    recent_violations = context.metadata['recent_violations'].to_i
    account_age = context.metadata['account_age_days'].to_i
    
    # Escalate if user has pattern of violations
    user_violations >= 3 && 
    recent_violations >= 2 && 
    account_age > 30 &&
    context.severity >= 5
  end
  
  suspend_account duration: 'indefinite', reason: 'Repeat offender pattern'
  add_penalty points: 150, reason: 'Escalated penalty for repeat violations'
  notify_support priority: :critical, message: 'Repeat offender requires review'
end
```

### Custom Outcomes

```ruby
rule 'custom_action_rule', priority: 40 do
  when { |ctx| ctx.type == :custom_violation }
  
  # Custom outcome using lambda
  then do |context|
    # Create multiple custom outcomes
    [
      CustomOutcome.new(context, action: :custom_action, data: { key: 'value' }),
      RuleEngine::LogViolation.new(context, level: :info, details: 'Custom processing')
    ]
  end
end
```

## Configuration-Based Rules

### YAML Configuration

```yaml
# config/rules/content_moderation.yaml
content_moderation:
  strategy: collect_all
  metadata:
    description: "Content moderation rules"
    version: "2.0"
  rules:
    - name: "hate_speech_detection"
      priority: 95
      enabled: true
      metadata:
        category: "safety"
        auto_created: false
      condition:
        type: and
        conditions:
          - type: field_equals
            field: type
            value: inappropriate_content
          - type: field_greater_than
            field: severity
            value: 8
          - type: custom
            code: "context.metadata['hate_speech_confidence'].to_f > 0.8"
      outcomes:
        - type: suspend_account
          duration: "7"
          reason: "Hate speech detected"
        - type: add_penalty
          points: 80
          reason: "Hate speech violation"
        - type: notify_support
          priority: high
          message: "Hate speech content requires review"
        - type: block_action
          action_type: posting
          reason: "Content posting blocked due to hate speech"

    - name: "spam_content_detection"
      priority: 60
      enabled: true
      condition:
        type: and
        conditions:
          - type: field_equals
            field: type
            value: spam
          - type: field_greater_than
            field: severity
            value: 5
          - type: custom
            code: "context.metadata['spam_score'].to_f > 0.7"
      outcomes:
        - type: add_penalty
          points: 30
          reason: "Spam content detected"
        - type: notify_user
          message: "Your content has been flagged as spam"
          channel: email
        - type: log_violation
          level: warn
          details: "Spam content detected and penalized"
```

### Loading Configuration

```ruby
# Load rules from YAML
engine = RuleEngine::RuleEngine.new
engine.load_from_config('config/rules/content_moderation.yaml')

# Or load multiple files
Dir['config/rules/*.yaml'].each do |file|
  engine.load_from_config(file)
end
```

## Advanced Rule Patterns

### 1. Time-Based Rules

```ruby
rule 'weekend_leniency', priority: 5 do
  when do |context|
    # Apply more lenient rules on weekends
    (Time.current.saturday? || Time.current.sunday?) && 
    context.severity <= 6
  end
  
  # Reduce penalty by 50% on weekends
  add_penalty points: (context.severity * 5 * 0.5).to_i, reason: 'Weekend leniency applied'
end

rule 'business_hours_escalation', priority: 85 do
  when do |context|
    # Escalate during business hours for faster response
    business_hours = (9..17).cover?(Time.current.hour)
    weekday = (1..5).cover?(Time.current.wday)
    
    business_hours && weekday && context.severity >= 7
  end
  
  notify_support priority: :high, message: 'Business hours escalation'
end
```

### 2. User Behavior Patterns

```ruby
rule 'velocity_based_detection', priority: 70 do
  when do |context|
    # Detect rapid succession of violations
    recent_violations = context.metadata['recent_violations'].to_i
    time_window_hours = context.metadata['violation_time_window'].to_i
    
    recent_violations >= 3 && time_window_hours <= 24
  end
  
  suspend_account duration: '48', reason: 'Rapid violation pattern detected'
  notify_support priority: :medium, message: 'User showing rapid violation pattern'
end

rule 'geographic_anomaly', priority: 65 do
  when do |context|
    # Flag violations from unusual locations
    usual_country = context.metadata['usual_country']
    current_country = context.metadata['current_country']
    
    usual_country && current_country && usual_country != current_country
  end
  
  add_penalty points: 10, reason: 'Geographic anomaly detected'
  notify_support priority: :low, message: 'User violation from unusual location'
end
```

### 3. Contextual Rules

```ruby
rule 'first_time_user_leniency', priority: 10 do
  when do |context|
    account_age_days = context.metadata['account_age_days'].to_i
    total_violations = context.metadata['total_violations'].to_i
    
    account_age_days <= 7 && total_violations <= 1 && context.severity <= 5
  end
  
  # More lenient treatment for new users
  add_penalty points: 5, reason: 'First-time user - reduced penalty'
  notify_user message: 'Welcome! Please review our community guidelines.', channel: :email
end

rule 'high_value_user_protection', priority: 15 do
  when do |context|
    user_tier = context.metadata['user_tier']
    account_value = context.metadata['account_value'].to_f
    
    (user_tier == 'premium' || account_value > 1000) && context.severity <= 6
  end
  
  # Reduced penalties for high-value users
  add_penalty points: (context.severity * 3), reason: 'High-value user consideration'
  notify_support priority: :medium, message: 'High-value user violation'
end
```

### 4. Machine Learning Integration

```ruby
rule 'ml_fraud_detection', priority: 88 do
  when do |context|
    # Use ML model predictions
    fraud_probability = context.metadata['ml_fraud_probability'].to_f
    model_confidence = context.metadata['ml_confidence'].to_f
    
    fraud_probability > 0.8 && model_confidence > 0.9
  end
  
  suspend_account duration: '7', reason: 'ML fraud detection (high confidence)'
  add_penalty points: 60, reason: 'ML-detected fraud'
  notify_support priority: :high, message: 'ML model detected high-probability fraud'
end

rule 'sentiment_based_moderation', priority: 45 do
  when do |context|
    sentiment_score = context.metadata['sentiment_score'].to_f
    toxicity_score = context.metadata['toxicity_score'].to_f
    
    sentiment_score < -0.7 || toxicity_score > 0.8
  end
  
  add_penalty points: 25, reason: 'Negative sentiment/toxic content detected'
  notify_user message: 'Please keep discussions respectful', channel: :email
end
```

## Rails API Integration

### Service Integration

```ruby
# In your Rails application
class ViolationProcessingService
  include RuleEngine::DSL
  include RuleEngine::DSL::ConditionHelpers
  
  def initialize
    @engine = RuleEngine::RuleEngine.new
    setup_handlers
    setup_rules
  end
  
  def process_violation(violation)
    context = build_context(violation)
    result = @engine.evaluate_and_dispatch('violation_processing', context)
    apply_to_database(result, violation)
  end
  
  private
  
  def setup_rules
    # Define rules specific to your application
    rules = define_rule_set('violation_processing') do
      rule 'account_takeover_detection', priority: 95 do
        when do |ctx|
          all_of(
            violation_type(:fraud),
            severity_at_least(8),
            metadata_contains('pattern', 'account_takeover')
          ).call(ctx)
        end
        
        suspend_account duration: 'indefinite', reason: 'Account takeover detected'
        add_penalty points: 100, reason: 'Account takeover'
        notify_support priority: :critical, message: 'Possible account takeover'
      end
    end
    
    @engine.add_rule_set(rules)
  end
  
  def build_context(violation)
    RuleEngine::ViolationContext.new(
      type: violation.violation_type.to_sym,
      severity: violation.severity,
      user_id: violation.user_id,
      metadata: violation.metadata.merge(
        'user_history' => build_user_history(violation.user),
        'risk_factors' => calculate_risk_factors(violation)
      )
    )
  end
end
```

### API Endpoint Usage

```ruby
# In your controller
class ViolationsController < ApplicationController
  def create
    violation = Violation.create!(violation_params)
    
    if params[:auto_process]
      result = ViolationProcessingService.new.process_violation(violation)
      render json: { violation: violation, processing_result: result }
    else
      render json: { violation: violation }
    end
  end
end
```

## Best Practices

### 1. Rule Organization

```ruby
# Group related rules together
fraud_rules = define_rule_set('fraud_detection', strategy: :collect_all) do
  # High priority rules first
  rule 'critical_fraud', priority: 100 do
    # Critical fraud handling
  end
  
  rule 'high_fraud', priority: 80 do
    # High fraud handling
  end
  
  rule 'medium_fraud', priority: 50 do
    # Medium fraud handling
  end
end

spam_rules = define_rule_set('spam_detection', strategy: :first_match) do
  # Use first_match for spam to avoid duplicate penalties
end
```

### 2. Condition Design

```ruby
# Good: Clear, readable conditions
rule 'clear_condition_example', priority: 50 do
  when do |context|
    is_fraud = context.type == :fraud
    is_severe = context.severity >= 7
    is_automated = context.metadata['source'] == 'automated'
    
    is_fraud && is_severe && is_automated
  end
end

# Better: Use helper methods
rule 'helper_method_example', priority: 50 do
  when do |context|
    all_of(
      violation_type(:fraud),
      severity_at_least(7),
      metadata_contains('source', 'automated')
    ).call(context)
  end
end
```

### 3. Testing Rules

```ruby
# Test individual rules
RSpec.describe 'Fraud Detection Rules' do
  let(:engine) { RuleEngine::RuleEngine.new }
  let(:rule_set) { create_fraud_rules }
  
  before { engine.add_rule_set(rule_set) }
  
  it 'suspends account for critical fraud' do
    context = RuleEngine::ViolationContext.new(
      type: :fraud,
      severity: 9,
      user_id: 123,
      metadata: { 'source' => 'automated' }
    )
    
    result = engine.evaluate('fraud_detection', context)
    expect(result).to include(instance_of(RuleEngine::SuspendAccount))
  end
end
```

### 4. Performance Optimization

```ruby
# Use appropriate evaluation strategies
fast_rules = define_rule_set('quick_checks', strategy: :first_match) do
  # Stop at first match for simple checks
end

comprehensive_rules = define_rule_set('thorough_analysis', strategy: :collect_all) do
  # Evaluate all rules for comprehensive analysis
end

# Cache expensive calculations
rule 'cached_calculation', priority: 50 do
  when do |context|
    @cached_result ||= expensive_calculation(context)
    @cached_result > threshold
  end
end
```

### 5. Error Handling

```ruby
rule 'safe_rule_example', priority: 50 do
  when do |context|
    begin
      risky_calculation(context) > threshold
    rescue => e
      Rails.logger.error "Rule evaluation error: #{e.message}"
      false # Default to not triggering on errors
    end
  end
  
  add_penalty points: 25, reason: 'Safe violation handling'
end
```

### 6. Documentation and Metadata

```ruby
rule 'well_documented_rule', priority: 50, metadata: {
  description: 'Detects coordinated spam attacks',
  category: 'spam_detection',
  author: 'security_team',
  created_at: '2024-01-15',
  last_updated: '2024-03-20',
  test_cases: [
    { input: { type: :spam, severity: 8 }, expected: 'penalty' },
    { input: { type: :spam, severity: 3 }, expected: 'no_action' }
  ]
} do
  when { |ctx| ctx.type == :spam && ctx.severity >= 6 }
  add_penalty points: 30, reason: 'Coordinated spam detected'
end
```

This comprehensive guide covers all aspects of building rules with the Rule Engine. Start with basic DSL usage and gradually incorporate more advanced patterns as needed for your specific use case.
