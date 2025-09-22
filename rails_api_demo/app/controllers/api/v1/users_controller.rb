class Api::V1::UsersController < ApplicationController
  before_action :set_user, only: [:show, :update, :violations, :penalties, :suspend, :unsuspend]
  
  # GET /api/v1/users
  def index
    users = User.order(created_at: :desc)
               .page(params[:page])
               .per(params[:per_page] || 25)
    
    # Apply filters
    users = users.where(status: params[:status]) if params[:status].present?
    users = users.where('username ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    
    render_success({
      users: users.map { |u| user_json(u) },
      pagination: {
        current_page: users.current_page,
        total_pages: users.total_pages,
        total_count: users.total_count
      }
    })
  end
  
  # GET /api/v1/users/:id
  def show
    render_success(user_json(@user, detailed: true))
  end
  
  # POST /api/v1/users
  def create
    user = User.new(user_params)
    
    if user.save
      render_success(user_json(user), status: :created)
    else
      render_unprocessable_entity(ActiveRecord::RecordInvalid.new(user))
    end
  end
  
  # PATCH/PUT /api/v1/users/:id
  def update
    if @user.update(user_params)
      render_success(user_json(@user))
    else
      render_unprocessable_entity(ActiveRecord::RecordInvalid.new(@user))
    end
  end
  
  # GET /api/v1/users/:id/violations
  def violations
    violations = @user.violations.includes(:penalties)
                     .order(created_at: :desc)
                     .page(params[:page])
                     .per(params[:per_page] || 25)
    
    render_success({
      user: user_json(@user),
      violations: violations.map { |v| violation_summary_json(v) },
      pagination: {
        current_page: violations.current_page,
        total_pages: violations.total_pages,
        total_count: violations.total_count
      }
    })
  end
  
  # GET /api/v1/users/:id/penalties
  def penalties
    penalties = @user.penalties.order(created_at: :desc)
                     .page(params[:page])
                     .per(params[:per_page] || 25)
    
    active_penalties = @user.active_penalties
    total_points = @user.total_penalty_points
    
    render_success({
      user: user_json(@user),
      penalties: penalties.map { |p| penalty_json(p) },
      summary: {
        total_points: total_points,
        active_penalties_count: active_penalties.count,
        total_penalties_count: @user.penalties.count
      },
      pagination: {
        current_page: penalties.current_page,
        total_pages: penalties.total_pages,
        total_count: penalties.total_count
      }
    })
  end
  
  # POST /api/v1/users/:id/suspend
  def suspend
    duration = params[:duration]&.to_i
    reason = params[:reason] || 'Manual suspension'
    
    @user.suspend!(duration: duration, reason: reason)
    
    render_success({
      user: user_json(@user),
      message: "User suspended#{duration ? " for #{duration} days" : ' indefinitely'}"
    })
  end
  
  # POST /api/v1/users/:id/unsuspend
  def unsuspend
    if @user.suspended?
      @user.unsuspend!
      render_success({
        user: user_json(@user),
        message: 'User unsuspended successfully'
      })
    else
      render_error('User is not currently suspended')
    end
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  end
  
  def user_params
    params.require(:user).permit(:username, :email, :first_name, :last_name)
  end
  
  def user_json(user, detailed: false)
    data = {
      id: user.id,
      username: user.username,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      status: user.status,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
    
    if user.suspended?
      data[:suspension] = {
        suspended_at: user.suspended_at,
        expires_at: user.suspension_expires_at,
        reason: user.suspension_reason,
        is_indefinite: user.suspension_expires_at.nil?
      }
    end
    
    if detailed
      data[:stats] = {
        total_violations: user.violations.count,
        recent_violations: user.violations.recent.count,
        total_penalty_points: user.total_penalty_points,
        active_penalties: user.active_penalties.count,
        account_age_days: (Time.current - user.created_at).to_i / 1.day
      }
    end
    
    data
  end
  
  def violation_summary_json(violation)
    {
      id: violation.id,
      violation_type: violation.violation_type,
      severity: violation.severity,
      description: violation.description,
      status: violation.status,
      created_at: violation.created_at,
      penalties_count: violation.penalties.count
    }
  end
  
  def penalty_json(penalty)
    {
      id: penalty.id,
      penalty_type: penalty.penalty_type,
      points: penalty.points,
      reason: penalty.reason,
      expires_at: penalty.expires_at,
      active: penalty.active?,
      created_at: penalty.created_at,
      violation_id: penalty.violation_id
    }
  end
end
