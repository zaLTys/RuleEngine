require 'securerandom'

module RuleEngine
  # Base class for all rule outcomes
  # Outcomes represent the results of rule evaluation and are consumed by action handlers
  class Outcome
    attr_reader :context, :timestamp, :id

    def initialize(context, metadata: {})
      @context = context
      @metadata = metadata.freeze
      @timestamp = Time.now
      @id = SecureRandom.uuid
    end

    def to_h
      {
        id: @id,
        type: self.class.name,
        context: @context.to_h,
        metadata: @metadata,
        timestamp: @timestamp
      }
    end

    def ==(other)
      other.is_a?(self.class) && @id == other.id
    end

    def hash
      @id.hash
    end

    def eql?(other)
      self == other
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @context=#{@context.inspect}>"
    end
  end

  # Concrete outcome classes for common violation actions
  class AddPenalty < Outcome
    attr_reader :points, :reason

    def initialize(context, points:, reason: nil, metadata: {})
      super(context, metadata: metadata)
      @points = points.to_i
      @reason = reason
    end

    def to_h
      super.merge(points: @points, reason: @reason)
    end
  end

  class SuspendAccount < Outcome
    attr_reader :duration, :reason

    def initialize(context, duration: nil, reason: nil, metadata: {})
      super(context, metadata: metadata)
      @duration = duration
      @reason = reason
    end

    def to_h
      super.merge(duration: @duration, reason: @reason)
    end
  end

  class NotifySupport < Outcome
    attr_reader :priority, :message

    def initialize(context, priority: :medium, message: nil, metadata: {})
      super(context, metadata: metadata)
      @priority = priority.to_sym
      @message = message
    end

    def to_h
      super.merge(priority: @priority, message: @message)
    end
  end

  class NotifyUser < Outcome
    attr_reader :message, :channel

    def initialize(context, message:, channel: :email, metadata: {})
      super(context, metadata: metadata)
      @message = message
      @channel = channel.to_sym
    end

    def to_h
      super.merge(message: @message, channel: @channel)
    end
  end

  class LogViolation < Outcome
    attr_reader :level, :details

    def initialize(context, level: :info, details: nil, metadata: {})
      super(context, metadata: metadata)
      @level = level.to_sym
      @details = details
    end

    def to_h
      super.merge(level: @level, details: @details)
    end
  end

  class BlockAction < Outcome
    attr_reader :action_type, :reason

    def initialize(context, action_type:, reason: nil, metadata: {})
      super(context, metadata: metadata)
      @action_type = action_type.to_sym
      @reason = reason
    end

    def to_h
      super.merge(action_type: @action_type, reason: @reason)
    end
  end
end

