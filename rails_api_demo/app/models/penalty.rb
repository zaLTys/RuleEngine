class Penalty < ApplicationRecord
  belongs_to :user
  belongs_to :violation, optional: true
  
  validates :points, presence: true, numericality: { greater_than: 0 }
  validates :reason, presence: true
  validates :penalty_type, presence: true
  
  enum penalty_type: { 
    warning: 0, 
    point_penalty: 1, 
    temporary_suspension: 2, 
    permanent_suspension: 3,
    feature_restriction: 4,
    content_removal: 5
  }
  
  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at IS NOT NULL AND expires_at <= ?', Time.current) }
  
  def active?
    expires_at.nil? || expires_at > Time.current
  end
  
  def expired?
    !active?
  end
end
