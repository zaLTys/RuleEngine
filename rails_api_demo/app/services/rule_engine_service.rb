class RuleEngineService
  include Singleton
  include RuleEngine::DSL
  include RuleEngine::DSL::ConditionHelpers
  
  def initialize
    @engine = RuleEngine::RuleEngine.new
    setup_handlers
    setup_default_rules
  end
  
  def process_violation(violation)
    return { success: false, error: 'Violation already processed' } if violation.processed?
    
    begin
      context = violation.to_violation_context
      
      # Evaluate rules and get outcomes
      result = @engine.evaluate_and_dispatch('violation_processing', context)
      
      # Apply outcomes to the database
      outcomes_applied = apply_outcomes_to_models(result[:outcomes], violation)
      
      # Mark violation as processed
      violation.update!(
        status: :processed,
        processed_at: Time.current,
        processing_result: {
          outcomes_count: result[:outcomes].count,
          outcomes_applied: outcomes_applied,
          rule_set: 'violation_processing'
        }
      )
      
      {
        success: true,
        outcomes: result[:outcomes].map { |o| outcome_summary(o) },
        outcomes_applied: outcomes_applied
      }
    rescue => e
      Rails.logger.error "Rule processing failed for violation #{violation.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def evaluate_violation(violation, rule_set_name: 'violation_processing')
    context = violation.to_violation_context
    result = @engine.evaluate(rule_set_name, context)
    
    {
      matching_rules: result.map { |outcome| outcome.metadata[:rule_name] }.compact.uniq,
      outcomes: result.map { |o| outcome_summary(o) }
    }
  end
  
  def engine_stats
    @engine.stats
  end
  
  def rule_sets
    @engine.rule_sets.keys
  end
  
  def add_custom_rule_set(name, &block)
    rule_set = define_rule_set(name, &block)
    @engine.add_rule_set(rule_set)
  end
  
  private
  
  def setup_handlers
    @engine.register_handlers(
      RailsPenaltyHandler.new,
      RailsAccountSuspensionHandler.new,
      RailsNotificationHandler.new,
      RailsLoggingHandler.new
    )
  end
  
  def setup_default_rules
    # Fraud detection rules
    fraud_rules = define_rule_set('fraud_detection', strategy: :collect_all) do
      rule 'critical_fraud', priority: 100 do
        when { |ctx| ctx.type == :fraud && ctx.severity >= 9 }
        suspend_account duration: 'indefinite', reason: 'Critical fraud detected'
        add_penalty points: 100, reason: 'Critical fraud violation'
        notify_support priority: :critical, message: 'Critical fraud requires immediate attention'
      end
      
      rule 'high_fraud', priority: 80 do
        when { |ctx| ctx.type == :fraud && ctx.severity >= 7 && ctx.severity < 9 }
        suspend_account duration: '30', reason: 'High severity fraud'
        add_penalty points: 75, reason: 'High severity fraud violation'
        notify_support priority: :high, message: 'High severity fraud detected'
      end
      
      rule 'medium_fraud', priority: 50 do
        when { |ctx| ctx.type == :fraud && ctx.severity >= 4 && ctx.severity < 7 }
        add_penalty points: 40, reason: 'Medium severity fraud'
        notify_user message: 'Fraudulent activity detected on your account', channel: :email
      end
    end
    
    # Spam detection rules
    spam_rules = define_rule_set('spam_detection', strategy: :first_match) do
      rule 'severe_spam', priority: 90 do
        when { |ctx| ctx.type == :spam && ctx.severity >= 8 }
        suspend_account duration: '14', reason: 'Severe spam violation'
        add_penalty points: 60, reason: 'Severe spam'
      end
      
      rule 'moderate_spam', priority: 50 do
        when { |ctx| ctx.type == :spam && ctx.severity >= 5 && ctx.severity < 8 }
        add_penalty points: 25, reason: 'Moderate spam'
        notify_user message: 'Please review our spam policy', channel: :email
      end
      
      rule 'light_spam', priority: 10 do
        when { |ctx| ctx.type == :spam && ctx.severity < 5 }
        add_penalty points: 5, reason: 'Light spam'
      end
    end
    
    # Combined violation processing
    violation_processing = define_rule_set('violation_processing', strategy: :collect_all) do
      # Repeat offender rules
      rule 'repeat_offender_critical', priority: 150 do
        when do |ctx|
          ctx.metadata['total_violations'].to_i >= 5 && 
          ctx.metadata['recent_violations'].to_i >= 3 &&
          ctx.severity >= 6
        end
        suspend_account duration: 'indefinite', reason: 'Repeat offender - critical violations'
        notify_support priority: :critical, message: 'Repeat offender with critical violations'
      end
      
      rule 'repeat_offender_warning', priority: 120 do
        when do |ctx|
          ctx.metadata['total_violations'].to_i >= 3 && 
          ctx.metadata['recent_violations'].to_i >= 2
        end
        add_penalty points: 20, reason: 'Repeat offender penalty'
        notify_user message: 'Multiple violations detected. Further violations may result in suspension.', channel: :email
      end
      
      # New account rules (more lenient)
      rule 'new_account_minor_violation', priority: 5 do
        when do |ctx|
          ctx.metadata['account_age_days'].to_i <= 7 && 
          ctx.severity <= 4 &&
          ctx.metadata['total_violations'].to_i <= 1
        end
        add_penalty points: 2, reason: 'New account - minor violation'
        notify_user message: 'Welcome! Please review our community guidelines.', channel: :email
      end
      
      # Include specific violation type rules
      rule 'fraud_processing', priority: 100 do
        when { |ctx| ctx.type == :fraud }
        then do |ctx|
          fraud_result = @engine.evaluate('fraud_detection', ctx)
          fraud_result
        end
      end
      
      rule 'spam_processing', priority: 90 do
        when { |ctx| ctx.type == :spam }
        then do |ctx|
          spam_result = @engine.evaluate('spam_detection', ctx)
          spam_result
        end
      end
      
      # Harassment rules
      rule 'severe_harassment', priority: 95 do
        when { |ctx| ctx.type == :harassment && ctx.severity >= 7 }
        suspend_account duration: '30', reason: 'Severe harassment'
        add_penalty points: 80, reason: 'Severe harassment violation'
        block_action action_type: :messaging, reason: 'Harassment prevention'
      end
      
      rule 'moderate_harassment', priority: 60 do
        when { |ctx| ctx.type == :harassment && ctx.severity >= 4 && ctx.severity < 7 }
        add_penalty points: 30, reason: 'Harassment violation'
        notify_user message: 'Harassment is not tolerated. Please review our community guidelines.', channel: :email
      end
      
      # Inappropriate content rules
      rule 'severe_inappropriate_content', priority: 85 do
        when { |ctx| ctx.type == :inappropriate_content && ctx.severity >= 8 }
        suspend_account duration: '7', reason: 'Severe inappropriate content'
        add_penalty points: 50, reason: 'Inappropriate content violation'
      end
      
      rule 'moderate_inappropriate_content', priority: 40 do
        when { |ctx| ctx.type == :inappropriate_content && ctx.severity >= 4 && ctx.severity < 8 }
        add_penalty points: 20, reason: 'Inappropriate content'
        notify_user message: 'Content removed for policy violation', channel: :email
      end
    end
    
    @engine.add_rule_set(fraud_rules)
    @engine.add_rule_set(spam_rules)
    @engine.add_rule_set(violation_processing)
  end
  
  def apply_outcomes_to_models(outcomes, violation)
    applied = []
    
    outcomes.each do |outcome|
      case outcome
      when RuleEngine::AddPenalty
        penalty = violation.user.penalties.create!(
          violation: violation,
          penalty_type: :point_penalty,
          points: outcome.points,
          reason: outcome.reason,
          expires_at: outcome.duration ? Time.current + outcome.duration.to_i.days : nil,
          metadata: { rule_outcome: true, outcome_class: outcome.class.name }
        )
        applied << { type: 'penalty', id: penalty.id, points: outcome.points }
        
      when RuleEngine::SuspendAccount
        violation.user.suspend!(
          duration: outcome.duration == 'indefinite' ? nil : outcome.duration,
          reason: outcome.reason
        )
        applied << { type: 'suspension', duration: outcome.duration, reason: outcome.reason }
        
      when RuleEngine::NotifyUser
        # In a real app, this would trigger email/SMS/push notifications
        Rails.logger.info "Notifying user #{violation.user_id}: #{outcome.message}"
        applied << { type: 'user_notification', message: outcome.message, channel: outcome.channel }
        
      when RuleEngine::NotifySupport
        # In a real app, this would create support tickets or alerts
        Rails.logger.warn "Support notification (#{outcome.priority}): #{outcome.message} for user #{violation.user_id}"
        applied << { type: 'support_notification', priority: outcome.priority, message: outcome.message }
        
      when RuleEngine::LogViolation
        Rails.logger.send(outcome.level, "Violation logged: #{outcome.details || violation.description}")
        applied << { type: 'log_entry', level: outcome.level }
        
      when RuleEngine::BlockAction
        # In a real app, this would update user permissions/restrictions
        Rails.logger.info "Blocking action #{outcome.action_type} for user #{violation.user_id}: #{outcome.reason}"
        applied << { type: 'action_block', action_type: outcome.action_type, reason: outcome.reason }
      end
    end
    
    applied
  end
  
  def outcome_summary(outcome)
    {
      type: outcome.class.name.demodulize.underscore,
      details: outcome_details(outcome)
    }
  end
  
  def outcome_details(outcome)
    case outcome
    when RuleEngine::AddPenalty
      { points: outcome.points, reason: outcome.reason, duration: outcome.duration }
    when RuleEngine::SuspendAccount
      { duration: outcome.duration, reason: outcome.reason }
    when RuleEngine::NotifyUser
      { message: outcome.message, channel: outcome.channel }
    when RuleEngine::NotifySupport
      { priority: outcome.priority, message: outcome.message }
    when RuleEngine::LogViolation
      { level: outcome.level, details: outcome.details }
    when RuleEngine::BlockAction
      { action_type: outcome.action_type, reason: outcome.reason }
    else
      { class: outcome.class.name }
    end
  end
end
