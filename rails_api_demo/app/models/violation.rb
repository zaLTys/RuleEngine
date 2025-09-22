class Violation < ApplicationRecord
  belongs_to :user
  has_many :penalties, dependent: :destroy
  
  validates :violation_type, presence: true
  validates :severity, presence: true, inclusion: { in: 1..10 }
  validates :description, presence: true
  
  enum status: { pending: 0, processed: 1, dismissed: 2 }
  enum violation_type: { 
    fraud: 0, 
    spam: 1, 
    harassment: 2, 
    inappropriate_content: 3, 
    account_abuse: 4,
    policy_violation: 5
  }
  
  scope :recent, -> { where('created_at > ?', 30.days.ago) }
  scope :by_severity, ->(min_severity) { where('severity >= ?', min_severity) }
  scope :by_type, ->(type) { where(violation_type: type) }
  
  def to_violation_context
    RuleEngine::ViolationContext.new(
      type: violation_type.to_sym,
      severity: severity,
      user_id: user_id,
      metadata: {
        'violation_id' => id,
        'description' => description,
        'reported_by' => reported_by,
        'source' => source || 'manual',
        'timestamp' => created_at.iso8601,
        'user_history' => user_violation_summary
      }.merge(metadata || {})
    )
  end
  
  private
  
  def user_violation_summary
    {
      'total_violations' => user.violations.count,
      'recent_violations' => user.violations.recent.count,
      'total_penalty_points' => user.total_penalty_points,
      'account_age_days' => (Time.current - user.created_at).to_i / 1.day
    }
  end
end
