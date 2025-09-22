class Api::V1::HealthController < ApplicationController
  def check
    health_data = {
      status: 'healthy',
      timestamp: Time.current.iso8601,
      version: '1.0.0',
      environment: Rails.env,
      database: database_status,
      rule_engine: rule_engine_status
    }
    
    render_success(health_data)
  end
  
  private
  
  def database_status
    {
      connected: ActiveRecord::Base.connected?,
      users_count: User.count,
      violations_count: Violation.count,
      penalties_count: Penalty.count
    }
  rescue => e
    {
      connected: false,
      error: e.message
    }
  end
  
  def rule_engine_status
    {
      rule_sets: rule_engine_service.rule_sets,
      stats: rule_engine_service.engine_stats
    }
  rescue => e
    {
      error: e.message
    }
  end
end
