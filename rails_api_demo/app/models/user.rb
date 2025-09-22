class User < ApplicationRecord
  has_many :violations, dependent: :destroy
  has_many :penalties, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
  
  enum status: { active: 0, suspended: 1, banned: 2 }
  
  def total_penalty_points
    penalties.sum(:points)
  end
  
  def active_penalties
    penalties.where('expires_at IS NULL OR expires_at > ?', Time.current)
  end
  
  def violation_history
    violations.includes(:penalties).order(created_at: :desc)
  end
  
  def suspend!(duration: nil, reason: nil)
    update!(
      status: :suspended,
      suspended_at: Time.current,
      suspension_expires_at: duration ? Time.current + duration.to_i.days : nil,
      suspension_reason: reason
    )
  end
  
  def unsuspend!
    update!(
      status: :active,
      suspended_at: nil,
      suspension_expires_at: nil,
      suspension_reason: nil
    )
  end
  
  def suspended?
    status == 'suspended' && (suspension_expires_at.nil? || suspension_expires_at > Time.current)
  end
end
