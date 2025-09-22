class ApplicationController < ActionController::API
  include ActionController::Helpers
  
  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  rescue_from StandardError, with: :render_internal_server_error
  
  protected
  
  def render_success(data = {}, status: :ok)
    render json: {
      success: true,
      data: data,
      timestamp: Time.current.iso8601
    }, status: status
  end
  
  def render_error(message, status: :bad_request, details: nil)
    render json: {
      success: false,
      error: {
        message: message,
        details: details
      },
      timestamp: Time.current.iso8601
    }, status: status
  end
  
  def render_not_found(exception = nil)
    message = exception&.message || 'Resource not found'
    render_error(message, status: :not_found)
  end
  
  def render_unprocessable_entity(exception)
    render_error(
      'Validation failed',
      status: :unprocessable_entity,
      details: exception.record.errors.full_messages
    )
  end
  
  def render_internal_server_error(exception)
    Rails.logger.error "Internal server error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render_error(
      'Internal server error',
      status: :internal_server_error,
      details: Rails.env.development? ? exception.message : nil
    )
  end
  
  def rule_engine_service
    @rule_engine_service ||= RuleEngineService.instance
  end
end
