class Api::V1::AnalyticsController < ApplicationController
  
  # GET /api/v1/analytics/violations
  def violations
    date_range = date_range_params
    
    violations_data = {
      total_count: Violation.where(created_at: date_range).count,
      by_type: violation_counts_by_type(date_range),
      by_severity: violation_counts_by_severity(date_range),
      by_status: violation_counts_by_status(date_range),
      daily_trend: daily_violation_trend(date_range),
      top_users: top_violating_users(date_range)
    }
    
    render_success(violations_data)
  end
  
  # GET /api/v1/analytics/penalties
  def penalties
    date_range = date_range_params
    
    penalties_data = {
      total_count: Penalty.where(created_at: date_range).count,
      total_points: Penalty.where(created_at: date_range).sum(:points),
      by_type: penalty_counts_by_type(date_range),
      active_penalties: Penalty.active.count,
      expired_penalties: Penalty.expired.count,
      average_points: Penalty.where(created_at: date_range).average(:points)&.round(2),
      top_penalized_users: top_penalized_users(date_range)
    }
    
    render_success(penalties_data)
  end
  
  # GET /api/v1/analytics/rule_performance
  def rule_performance
    date_range = date_range_params
    
    # This would typically be stored in a separate analytics table
    # For now, we'll derive it from violation processing results
    violations = Violation.processed.where(processed_at: date_range)
    
    rule_performance_data = {
      total_processed: violations.count,
      average_processing_time: calculate_average_processing_time(violations),
      rule_trigger_frequency: analyze_rule_triggers(violations),
      outcome_distribution: analyze_outcome_distribution(violations),
      success_rate: calculate_success_rate(violations)
    }
    
    render_success(rule_performance_data)
  end
  
  private
  
  def date_range_params
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current
    start_date.beginning_of_day..end_date.end_of_day
  end
  
  def violation_counts_by_type(date_range)
    Violation.where(created_at: date_range)
             .group(:violation_type)
             .count
             .transform_keys(&:humanize)
  end
  
  def violation_counts_by_severity(date_range)
    Violation.where(created_at: date_range)
             .group(:severity)
             .count
             .sort_by { |severity, _| severity }
             .to_h
  end
  
  def violation_counts_by_status(date_range)
    Violation.where(created_at: date_range)
             .group(:status)
             .count
             .transform_keys(&:humanize)
  end
  
  def daily_violation_trend(date_range)
    Violation.where(created_at: date_range)
             .group_by_day(:created_at)
             .count
  end
  
  def top_violating_users(date_range, limit = 10)
    User.joins(:violations)
        .where(violations: { created_at: date_range })
        .group('users.id', 'users.username')
        .select('users.id, users.username, COUNT(violations.id) as violation_count')
        .order('violation_count DESC')
        .limit(limit)
        .map do |user|
          {
            user_id: user.id,
            username: user.username,
            violation_count: user.violation_count.to_i
          }
        end
  end
  
  def penalty_counts_by_type(date_range)
    Penalty.where(created_at: date_range)
           .group(:penalty_type)
           .count
           .transform_keys(&:humanize)
  end
  
  def top_penalized_users(date_range, limit = 10)
    User.joins(:penalties)
        .where(penalties: { created_at: date_range })
        .group('users.id', 'users.username')
        .select('users.id, users.username, SUM(penalties.points) as total_points')
        .order('total_points DESC')
        .limit(limit)
        .map do |user|
          {
            user_id: user.id,
            username: user.username,
            total_points: user.total_points.to_i
          }
        end
  end
  
  def calculate_average_processing_time(violations)
    times = violations.map do |v|
      next unless v.processed_at && v.created_at
      (v.processed_at - v.created_at) * 1000 # Convert to milliseconds
    end.compact
    
    return 0 if times.empty?
    (times.sum / times.size).round(2)
  end
  
  def analyze_rule_triggers(violations)
    # Extract rule trigger information from processing results
    rule_triggers = Hash.new(0)
    
    violations.each do |violation|
      next unless violation.processing_result.is_a?(Hash)
      
      outcomes = violation.processing_result['outcomes'] || []
      outcomes.each do |outcome|
        rule_name = outcome.dig('metadata', 'rule_name') || 'unknown'
        rule_triggers[rule_name] += 1
      end
    end
    
    rule_triggers.sort_by { |_, count| -count }.to_h
  end
  
  def analyze_outcome_distribution(violations)
    outcome_counts = Hash.new(0)
    
    violations.each do |violation|
      next unless violation.processing_result.is_a?(Hash)
      
      outcomes = violation.processing_result['outcomes'] || []
      outcomes.each do |outcome|
        outcome_type = outcome['type'] || 'unknown'
        outcome_counts[outcome_type] += 1
      end
    end
    
    outcome_counts.sort_by { |_, count| -count }.to_h
  end
  
  def calculate_success_rate(violations)
    return 100.0 if violations.empty?
    
    successful = violations.count { |v| v.processing_result.is_a?(Hash) && v.processing_result['success'] != false }
    ((successful.to_f / violations.count) * 100).round(2)
  end
end
