module RuleEngine
  # Base class for action handlers that process rule outcomes
  class ActionHandler
    attr_reader :name, :enabled

    def initialize(name:, enabled: true)
      @name = name.to_s
      @enabled = enabled
    end

    def enabled?
      @enabled
    end

    def disabled?
      !@enabled
    end

    def enable!
      @enabled = true
    end

    def disable!
      @enabled = false
    end

    # Override in subclasses to handle specific outcome types
    def handle(outcome)
      raise NotImplementedError, "Subclasses must implement #handle method"
    end

    def can_handle?(outcome)
      raise NotImplementedError, "Subclasses must implement #can_handle? method"
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @name=#{@name} @enabled=#{@enabled}>"
    end
  end

  # Concrete action handlers for common outcomes
  class PenaltyHandler < ActionHandler
    def initialize(name: 'PenaltyHandler', **options)
      super(name: name, **options)
    end

    def can_handle?(outcome)
      outcome.is_a?(AddPenalty)
    end

    def handle(outcome)
      return unless can_handle?(outcome) && enabled?

      puts "Adding #{outcome.points} penalty points to user #{outcome.context.user_id}"
      # Implement actual penalty logic here
      # e.g., update user record, send notification, etc.
    end
  end

  class AccountSuspensionHandler < ActionHandler
    def initialize(name: 'AccountSuspensionHandler', **options)
      super(name: name, **options)
    end

    def can_handle?(outcome)
      outcome.is_a?(SuspendAccount)
    end

    def handle(outcome)
      return unless can_handle?(outcome) && enabled?

      duration = outcome.duration || 'indefinite'
      reason = outcome.reason || 'Policy violation'
      
      puts "Suspending account #{outcome.context.user_id} for #{duration}. Reason: #{reason}"
      # Implement actual suspension logic here
      # e.g., update user status, send notification, etc.
    end
  end

  class NotificationHandler < ActionHandler
    def initialize(name: 'NotificationHandler', **options)
      super(name: name, **options)
    end

    def can_handle?(outcome)
      outcome.is_a?(NotifySupport) || outcome.is_a?(NotifyUser)
    end

    def handle(outcome)
      return unless can_handle?(outcome) && enabled?

      case outcome
      when NotifySupport
        priority = outcome.priority || :medium
        message = outcome.message || "Violation detected: #{outcome.context.type}"
        puts "Sending support notification (priority: #{priority}): #{message}"
      when NotifyUser
        channel = outcome.channel || :email
        message = outcome.message
        puts "Sending user notification via #{channel}: #{message}"
      end
      # Implement actual notification logic here
    end
  end

  class LoggingHandler < ActionHandler
    def initialize(name: 'LoggingHandler', **options)
      super(name: name, **options)
    end

    def can_handle?(outcome)
      outcome.is_a?(LogViolation)
    end

    def handle(outcome)
      return unless can_handle?(outcome) && enabled?

      level = outcome.level || :info
      details = outcome.details || outcome.context.to_h
      
      puts "Violation logged (#{level}): #{details}"
      # Implement actual logging logic here
    end
  end

  class ActionBlockingHandler < ActionHandler
    def initialize(name: 'ActionBlockingHandler', **options)
      super(name: name, **options)
    end

    def can_handle?(outcome)
      outcome.is_a?(BlockAction)
    end

    def handle(outcome)
      return unless can_handle?(outcome) && enabled?

      action_type = outcome.action_type
      reason = outcome.reason || 'Policy violation'
      
      puts "Blocking action '#{action_type}' for user #{outcome.context.user_id}. Reason: #{reason}"
      # Implement actual blocking logic here
    end
  end
end

