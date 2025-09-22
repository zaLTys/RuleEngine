# Rails API Demo - Rule Engine Integration

This Rails API demonstrates how to integrate and use the Rule Engine gem in a real-world application. It provides a complete violation management system with automated rule processing.

## Features

- **User Management**: Create and manage users with violation history
- **Violation Processing**: Automatically process violations using configurable rules
- **Penalty System**: Apply penalties, suspensions, and other actions based on rule outcomes
- **Analytics**: Track violation patterns and rule performance
- **RESTful API**: Complete REST API for all operations

## Quick Start

### 1. Setup

```bash
cd rails_api_demo
bundle install
rails db:create db:migrate db:seed
rails server
```

### 2. Test the API

The API will be available at `http://localhost:3000`

#### Health Check
```bash
curl http://localhost:3000/api/v1/health
```

#### List Users
```bash
curl http://localhost:3000/api/v1/users
```

#### Create a Violation
```bash
curl -X POST http://localhost:3000/api/v1/violations \
  -H "Content-Type: application/json" \
  -d '{
    "violation": {
      "user_id": 1,
      "violation_type": "fraud",
      "severity": 8,
      "description": "Suspicious transaction detected",
      "reported_by": "fraud_detection_system",
      "source": "automated"
    },
    "auto_process": "true"
  }'
```

## API Endpoints

### Users
- `GET /api/v1/users` - List all users
- `GET /api/v1/users/:id` - Get user details
- `POST /api/v1/users` - Create a new user
- `PATCH /api/v1/users/:id` - Update user
- `GET /api/v1/users/:id/violations` - Get user's violations
- `GET /api/v1/users/:id/penalties` - Get user's penalties
- `POST /api/v1/users/:id/suspend` - Manually suspend user
- `POST /api/v1/users/:id/unsuspend` - Unsuspend user

### Violations
- `GET /api/v1/violations` - List all violations
- `GET /api/v1/violations/:id` - Get violation details
- `POST /api/v1/violations` - Create a violation
- `POST /api/v1/violations/:id/process` - Process violation through rules
- `POST /api/v1/violations/:id/reprocess` - Reprocess violation

### Analytics
- `GET /api/v1/analytics/violations` - Violation statistics
- `GET /api/v1/analytics/penalties` - Penalty statistics
- `GET /api/v1/analytics/rule_performance` - Rule performance metrics

### System
- `GET /api/v1/health` - Health check and system status

## Rule Engine Integration

### How Rules Are Built

The rule engine uses a DSL (Domain Specific Language) to define rules:

```ruby
# Define a rule set
fraud_rules = define_rule_set('fraud_detection', strategy: :collect_all) do
  rule 'high_severity_fraud', priority: 100 do
    when { |ctx| ctx.type == :fraud && ctx.severity >= 8 }
    suspend_account duration: 'indefinite', reason: 'High severity fraud'
    add_penalty points: 100, reason: 'Critical fraud violation'
    notify_support priority: :critical, message: 'Critical fraud detected'
  end
end
```

### Rule Components

1. **Conditions**: Lambda functions that evaluate context
2. **Outcomes**: Actions to take when conditions are met
3. **Priority**: Determines rule execution order
4. **Metadata**: Additional rule information

### Available Outcomes

- `add_penalty(points:, reason:)` - Add penalty points
- `suspend_account(duration:, reason:)` - Suspend user account
- `notify_user(message:, channel:)` - Send notification to user
- `notify_support(priority:, message:)` - Alert support team
- `log_violation(level:, details:)` - Log violation details
- `block_action(action_type:, reason:)` - Block specific user actions

### Rule Processing Pipeline

1. **Violation Created** - API receives violation report
2. **Context Building** - Convert violation to rule context
3. **Rule Evaluation** - Engine evaluates matching rules
4. **Outcome Generation** - Rules produce outcome objects
5. **Action Dispatch** - Handlers execute outcomes
6. **Database Updates** - Results stored in database

## Example Usage Scenarios

### 1. Fraud Detection

```bash
# High severity fraud - triggers suspension
curl -X POST http://localhost:3000/api/v1/violations \
  -H "Content-Type: application/json" \
  -d '{
    "violation": {
      "user_id": 1,
      "violation_type": "fraud",
      "severity": 9,
      "description": "Credit card fraud detected",
      "metadata": {"amount": 1000, "merchant": "suspicious_store"}
    },
    "auto_process": "true"
  }'
```

### 2. Spam Detection

```bash
# Moderate spam - triggers penalty
curl -X POST http://localhost:3000/api/v1/violations \
  -H "Content-Type: application/json" \
  -d '{
    "violation": {
      "user_id": 2,
      "violation_type": "spam",
      "severity": 6,
      "description": "Multiple promotional posts",
      "metadata": {"post_count": 10}
    },
    "auto_process": "true"
  }'
```

### 3. Repeat Offender

```bash
# Create multiple violations for same user to trigger repeat offender rules
# (Run this after the user already has violations)
curl -X POST http://localhost:3000/api/v1/violations \
  -H "Content-Type: application/json" \
  -d '{
    "violation": {
      "user_id": 2,
      "violation_type": "harassment",
      "severity": 7,
      "description": "Harassment after previous warnings"
    },
    "auto_process": "true"
  }'
```

## Custom Rules

You can add custom rules at runtime:

```ruby
# Add a custom rule set
RuleEngineService.instance.add_custom_rule_set('custom_rules') do
  rule 'weekend_leniency', priority: 5 do
    when do |ctx|
      Time.current.saturday? || Time.current.sunday?
    end
    # Apply reduced penalties on weekends
    add_penalty points: ctx.severity * 0.5, reason: 'Weekend leniency applied'
  end
end
```

## Monitoring and Analytics

### View System Stats

```bash
curl http://localhost:3000/api/v1/analytics/violations
curl http://localhost:3000/api/v1/analytics/penalties
curl http://localhost:3000/api/v1/analytics/rule_performance
```

### Check Rule Engine Health

```bash
curl http://localhost:3000/api/v1/health
```

## Testing

Run the test suite:

```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec
```

## Configuration

### Environment Variables

- `RAILS_ENV` - Environment (development, test, production)
- `DATABASE_URL` - Database connection string
- `RULE_ENGINE_LOG_LEVEL` - Rule engine logging level

### Rule Configuration

Rules can be loaded from YAML files:

```yaml
# config/rules/custom_rules.yaml
custom_violations:
  strategy: collect_all
  rules:
    - name: "custom_rule"
      priority: 50
      condition:
        type: field_greater_than
        field: severity
        value: 5
      outcomes:
        - type: add_penalty
          points: 25
          reason: "Custom violation detected"
```

Load with:
```ruby
RuleEngineService.instance.engine.load_from_config('config/rules/custom_rules.yaml')
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Request   │───▶│  Rails Controller │───▶│ RuleEngineService│
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Database      │◀───│  Action Handlers │◀───│   Rule Engine   │
│   (Users,       │    │  (Rails-specific)│    │   (Core Logic)  │
│   Violations,   │    └──────────────────┘    └─────────────────┘
│   Penalties)    │
└─────────────────┘
```

## Production Considerations

1. **Performance**: Index database tables appropriately
2. **Monitoring**: Set up logging and metrics collection
3. **Scaling**: Consider async processing for high-volume violations
4. **Security**: Implement authentication and authorization
5. **Configuration**: Use environment-specific rule configurations
6. **Backup**: Regular database backups for audit trail

## Troubleshooting

### Common Issues

1. **Rules not firing**: Check condition logic and rule priority
2. **Database errors**: Ensure migrations have been run
3. **Performance issues**: Check database indexes and query optimization
4. **Rule conflicts**: Review rule priorities and conditions

### Debug Mode

Enable debug logging:
```ruby
Rails.logger.level = Logger::DEBUG
```

### Check Rule Engine Status

```bash
curl http://localhost:3000/api/v1/health | jq '.data.rule_engine'
```
