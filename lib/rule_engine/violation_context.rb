require 'securerandom'

module RuleEngine
  # Represents the input context for rule evaluation
  # Acts as the facts/data that rules evaluate against
  class ViolationContext
    attr_reader :type, :severity, :user_id, :metadata, :timestamp, :id

    def initialize(type:, severity:, user_id:, metadata: {}, timestamp: nil, id: nil)
      @type = type.to_sym
      @severity = severity.to_i
      @user_id = user_id
      @metadata = metadata.freeze
      @timestamp = timestamp || Time.now
      @id = id || SecureRandom.uuid
    end

    def to_h
      {
        id: @id,
        type: @type,
        severity: @severity,
        user_id: @user_id,
        metadata: @metadata,
        timestamp: @timestamp
      }
    end

    def ==(other)
      other.is_a?(ViolationContext) && @id == other.id
    end

    def hash
      @id.hash
    end

    def eql?(other)
      self == other
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @type=#{@type} @severity=#{@severity} @user_id=#{@user_id}>"
    end
  end
end

