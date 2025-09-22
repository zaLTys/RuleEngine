# Rails-specific action handlers that integrate with ActiveRecord models

class RailsPenaltyHandler < RuleEngine::ActionHandler
  def can_handle?(outcome)
    outcome.is_a?(RuleEngine::AddPenalty)
  end

  def handle(outcome)
    user = User.find(outcome.context.user_id)
    
    penalty = user.penalties.create!(
      penalty_type: :point_penalty,
      points: outcome.points,
      reason: outcome.reason,
      expires_at: outcome.duration ? Time.current + outcome.duration.to_i.days : nil,
      metadata: { 
        rule_outcome: true, 
        outcome_class: outcome.class.name,
        violation_id: outcome.context.metadata['violation_id']
      }
    )
    
    Rails.logger.info "Added penalty: #{outcome.points} points to user #{user.id} - #{outcome.reason}"
    penalty
  end
end

class RailsAccountSuspensionHandler < RuleEngine::ActionHandler
  def can_handle?(outcome)
    outcome.is_a?(RuleEngine::SuspendAccount)
  end

  def handle(outcome)
    user = User.find(outcome.context.user_id)
    
    duration_days = case outcome.duration
                   when 'indefinite', nil
                     nil
                   else
                     outcome.duration.to_i
                   end
    
    user.suspend!(duration: duration_days, reason: outcome.reason)
    
    Rails.logger.warn "Suspended user #{user.id} for #{outcome.duration || 'indefinite'} - #{outcome.reason}"
    user
  end
end

class RailsNotificationHandler < RuleEngine::ActionHandler
  def can_handle?(outcome)
    outcome.is_a?(RuleEngine::NotifyUser) || outcome.is_a?(RuleEngine::NotifySupport)
  end

  def handle(outcome)
    case outcome
    when RuleEngine::NotifyUser
      handle_user_notification(outcome)
    when RuleEngine::NotifySupport
      handle_support_notification(outcome)
    end
  end

  private

  def handle_user_notification(outcome)
    user = User.find(outcome.context.user_id)
    
    # In a real application, this would integrate with email/SMS/push notification services
    notification_data = {
      user_id: user.id,
      message: outcome.message,
      channel: outcome.channel,
      sent_at: Time.current,
      violation_id: outcome.context.metadata['violation_id']
    }
    
    case outcome.channel
    when :email
      # EmailService.send_violation_notice(user, outcome.message)
      Rails.logger.info "Email notification sent to user #{user.id}: #{outcome.message}"
    when :sms
      # SmsService.send_violation_notice(user, outcome.message)
      Rails.logger.info "SMS notification sent to user #{user.id}: #{outcome.message}"
    when :push
      # PushService.send_violation_notice(user, outcome.message)
      Rails.logger.info "Push notification sent to user #{user.id}: #{outcome.message}"
    end
    
    notification_data
  end

  def handle_support_notification(outcome)
    # In a real application, this would create support tickets or alerts
    support_data = {
      priority: outcome.priority,
      message: outcome.message,
      user_id: outcome.context.user_id,
      violation_id: outcome.context.metadata['violation_id'],
      created_at: Time.current
    }
    
    case outcome.priority
    when :critical, :high
      # Create urgent support ticket or alert
      Rails.logger.error "URGENT SUPPORT ALERT (#{outcome.priority}): #{outcome.message} for user #{outcome.context.user_id}"
      # SupportTicketService.create_urgent_ticket(support_data)
    when :medium
      Rails.logger.warn "Support notification (#{outcome.priority}): #{outcome.message} for user #{outcome.context.user_id}"
      # SupportTicketService.create_ticket(support_data)
    when :low
      Rails.logger.info "Support notification (#{outcome.priority}): #{outcome.message} for user #{outcome.context.user_id}"
    end
    
    support_data
  end
end

class RailsLoggingHandler < RuleEngine::ActionHandler
  def can_handle?(outcome)
    outcome.is_a?(RuleEngine::LogViolation)
  end

  def handle(outcome)
    log_data = {
      level: outcome.level,
      details: outcome.details,
      user_id: outcome.context.user_id,
      violation_type: outcome.context.type,
      severity: outcome.context.severity,
      violation_id: outcome.context.metadata['violation_id'],
      timestamp: Time.current
    }
    
    log_message = "Violation logged: #{outcome.details || 'Rule violation'} for user #{outcome.context.user_id}"
    
    Rails.logger.send(outcome.level, log_message)
    
    # In a real application, you might also store this in a dedicated audit log table
    # AuditLog.create!(log_data)
    
    log_data
  end
end

class RailsActionBlockHandler < RuleEngine::ActionHandler
  def can_handle?(outcome)
    outcome.is_a?(RuleEngine::BlockAction)
  end

  def handle(outcome)
    user = User.find(outcome.context.user_id)
    
    # In a real application, this would update user permissions or create restriction records
    block_data = {
      user_id: user.id,
      action_type: outcome.action_type,
      reason: outcome.reason,
      blocked_at: Time.current,
      violation_id: outcome.context.metadata['violation_id']
    }
    
    Rails.logger.info "Blocked action #{outcome.action_type} for user #{user.id}: #{outcome.reason}"
    
    # UserRestriction.create!(block_data)
    
    block_data
  end
end
