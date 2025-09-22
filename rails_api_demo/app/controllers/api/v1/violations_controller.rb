class Api::V1::ViolationsController < ApplicationController
  before_action :set_violation, only: [:show, :process, :reprocess]
  
  # GET /api/v1/violations
  def index
    violations = Violation.includes(:user, :penalties)
                         .order(created_at: :desc)
                         .page(params[:page])
                         .per(params[:per_page] || 25)
    
    # Apply filters
    violations = violations.by_type(params[:type]) if params[:type].present?
    violations = violations.by_severity(params[:min_severity]) if params[:min_severity].present?
    violations = violations.where(status: params[:status]) if params[:status].present?
    violations = violations.where(user_id: params[:user_id]) if params[:user_id].present?
    
    render_success({
      violations: violations.map { |v| violation_json(v) },
      pagination: {
        current_page: violations.current_page,
        total_pages: violations.total_pages,
        total_count: violations.total_count
      }
    })
  end
  
  # GET /api/v1/violations/:id
  def show
    render_success(violation_json(@violation, include_context: true))
  end
  
  # POST /api/v1/violations
  def create
    violation = Violation.new(violation_params)
    
    if violation.save
      # Automatically process the violation if requested
      if params[:auto_process] == 'true'
        result = rule_engine_service.process_violation(violation)
        render_success({
          violation: violation_json(violation.reload),
          processing_result: result
        }, status: :created)
      else
        render_success(violation_json(violation), status: :created)
      end
    else
      render_unprocessable_entity(ActiveRecord::RecordInvalid.new(violation))
    end
  end
  
  # POST /api/v1/violations/:id/process
  def process
    result = rule_engine_service.process_violation(@violation)
    
    if result[:success]
      render_success({
        violation: violation_json(@violation.reload),
        processing_result: result
      })
    else
      render_error(result[:error], status: :unprocessable_entity)
    end
  end
  
  # POST /api/v1/violations/:id/reprocess
  def reprocess
    # Reset violation status to allow reprocessing
    @violation.update!(status: :pending, processed_at: nil, processing_result: nil)
    
    result = rule_engine_service.process_violation(@violation)
    
    if result[:success]
      render_success({
        violation: violation_json(@violation.reload),
        processing_result: result
      })
    else
      render_error(result[:error], status: :unprocessable_entity)
    end
  end
  
  private
  
  def set_violation
    @violation = Violation.find(params[:id])
  end
  
  def violation_params
    params.require(:violation).permit(
      :user_id, :violation_type, :severity, :description, 
      :reported_by, :source, metadata: {}
    )
  end
  
  def violation_json(violation, include_context: false)
    data = {
      id: violation.id,
      user_id: violation.user_id,
      violation_type: violation.violation_type,
      severity: violation.severity,
      description: violation.description,
      status: violation.status,
      reported_by: violation.reported_by,
      source: violation.source,
      metadata: violation.metadata,
      created_at: violation.created_at,
      processed_at: violation.processed_at,
      processing_result: violation.processing_result,
      user: {
        id: violation.user.id,
        username: violation.user.username,
        email: violation.user.email,
        status: violation.user.status
      },
      penalties: violation.penalties.map { |p| penalty_json(p) }
    }
    
    if include_context
      data[:rule_context] = violation.to_violation_context.to_h
      data[:rule_evaluation] = rule_engine_service.evaluate_violation(violation)
    end
    
    data
  end
  
  def penalty_json(penalty)
    {
      id: penalty.id,
      penalty_type: penalty.penalty_type,
      points: penalty.points,
      reason: penalty.reason,
      expires_at: penalty.expires_at,
      active: penalty.active?,
      created_at: penalty.created_at
    }
  end
end
