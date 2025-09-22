#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# API Usage Examples for Rails Rule Engine Demo
# This script demonstrates how to interact with the Rails API

class ApiClient
  def initialize(base_url = 'http://localhost:3000')
    @base_url = base_url
  end
  
  def get(path)
    uri = URI("#{@base_url}#{path}")
    response = Net::HTTP.get_response(uri)
    parse_response(response)
  end
  
  def post(path, data)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = data.to_json
    
    response = http.request(request)
    parse_response(response)
  end
  
  private
  
  def parse_response(response)
    {
      status: response.code.to_i,
      body: JSON.parse(response.body),
      success: response.code.to_i < 300
    }
  rescue JSON::ParserError
    {
      status: response.code.to_i,
      body: response.body,
      success: false
    }
  end
end

# Initialize API client
client = ApiClient.new

puts "=== Rails Rule Engine API Demo ==="
puts "Starting API usage examples...\n"

# Example 1: Health Check
puts "1. Health Check"
response = client.get('/api/v1/health')
if response[:success]
  puts "✓ API is healthy"
  puts "  Rule sets: #{response[:body]['data']['rule_engine']['rule_sets']}"
else
  puts "✗ API health check failed"
  exit 1
end

# Example 2: Create Users
puts "\n2. Creating Users"
users_data = [
  { username: 'test_user_1', email: 'test1@example.com', first_name: 'Test', last_name: 'User1' },
  { username: 'test_user_2', email: 'test2@example.com', first_name: 'Test', last_name: 'User2' }
]

created_users = []
users_data.each_with_index do |user_data, index|
  response = client.post('/api/v1/users', { user: user_data })
  if response[:success]
    user = response[:body]['data']
    created_users << user
    puts "✓ Created user: #{user['username']} (ID: #{user['id']})"
  else
    puts "✗ Failed to create user #{index + 1}"
  end
end

# Example 3: High Severity Fraud Violation
puts "\n3. Creating High Severity Fraud Violation"
fraud_violation = {
  violation: {
    user_id: created_users[0]['id'],
    violation_type: 'fraud',
    severity: 9,
    description: 'Attempted credit card fraud with stolen information',
    reported_by: 'fraud_detection_system',
    source: 'payment_processor',
    metadata: {
      transaction_amount: 2500.00,
      card_number_last_four: '1234',
      merchant: 'suspicious_online_store',
      ip_address: '192.168.1.100'
    }
  },
  auto_process: 'true'
}

response = client.post('/api/v1/violations', fraud_violation)
if response[:success]
  violation = response[:body]['data']['violation']
  processing_result = response[:body]['data']['processing_result']
  
  puts "✓ Created and processed fraud violation (ID: #{violation['id']})"
  puts "  Status: #{violation['status']}"
  puts "  Outcomes applied: #{processing_result['outcomes_applied'].count}"
  puts "  User status: #{violation['user']['status']}"
  
  processing_result['outcomes'].each do |outcome|
    puts "    → #{outcome['type']}: #{outcome['details']}"
  end
else
  puts "✗ Failed to create fraud violation"
  puts "  Error: #{response[:body]['error']['message']}"
end

# Example 4: Moderate Spam Violation
puts "\n4. Creating Moderate Spam Violation"
spam_violation = {
  violation: {
    user_id: created_users[1]['id'],
    violation_type: 'spam',
    severity: 6,
    description: 'Posted identical promotional content across multiple forums',
    reported_by: 'content_moderator',
    source: 'forum_monitoring',
    metadata: {
      post_count: 15,
      forums: ['technology', 'gaming', 'lifestyle', 'business'],
      content_similarity: 0.95
    }
  },
  auto_process: 'true'
}

response = client.post('/api/v1/violations', spam_violation)
if response[:success]
  violation = response[:body]['data']['violation']
  processing_result = response[:body]['data']['processing_result']
  
  puts "✓ Created and processed spam violation (ID: #{violation['id']})"
  puts "  Outcomes applied: #{processing_result['outcomes_applied'].count}"
  
  processing_result['outcomes'].each do |outcome|
    puts "    → #{outcome['type']}: #{outcome['details']}"
  end
else
  puts "✗ Failed to create spam violation"
end

# Example 5: Create Multiple Violations for Repeat Offender Testing
puts "\n5. Creating Multiple Violations (Repeat Offender)"
repeat_violations = [
  {
    violation_type: 'harassment',
    severity: 7,
    description: 'Sent threatening messages to other users'
  },
  {
    violation_type: 'inappropriate_content',
    severity: 6,
    description: 'Posted content violating community guidelines'
  },
  {
    violation_type: 'policy_violation',
    severity: 5,
    description: 'Violated terms of service multiple times'
  }
]

repeat_violations.each_with_index do |violation_data, index|
  violation_request = {
    violation: violation_data.merge(
      user_id: created_users[1]['id'],
      reported_by: 'automated_system',
      source: 'violation_detection'
    ),
    auto_process: 'true'
  }
  
  response = client.post('/api/v1/violations', violation_request)
  if response[:success]
    violation = response[:body]['data']['violation']
    puts "✓ Created violation #{index + 1}: #{violation_data[:violation_type]}"
  else
    puts "✗ Failed to create violation #{index + 1}"
  end
end

# Example 6: Check User Status and Penalties
puts "\n6. Checking User Status and Penalties"
created_users.each_with_index do |user, index|
  # Get updated user info
  response = client.get("/api/v1/users/#{user['id']}")
  if response[:success]
    updated_user = response[:body]['data']
    puts "User #{index + 1} (#{updated_user['username']}):"
    puts "  Status: #{updated_user['status']}"
    puts "  Total violations: #{updated_user['stats']['total_violations']}"
    puts "  Total penalty points: #{updated_user['stats']['total_penalty_points']}"
    
    if updated_user['suspension']
      puts "  ⚠️  SUSPENDED: #{updated_user['suspension']['reason']}"
      if updated_user['suspension']['is_indefinite']
        puts "     Duration: Indefinite"
      else
        puts "     Expires: #{updated_user['suspension']['expires_at']}"
      end
    end
  end
end

# Example 7: Get Analytics
puts "\n7. Analytics Overview"

# Violations analytics
response = client.get('/api/v1/analytics/violations')
if response[:success]
  analytics = response[:body]['data']
  puts "Violation Analytics:"
  puts "  Total violations: #{analytics['total_count']}"
  puts "  By type: #{analytics['by_type']}"
  puts "  By severity: #{analytics['by_severity']}"
end

# Penalties analytics
response = client.get('/api/v1/analytics/penalties')
if response[:success]
  analytics = response[:body]['data']
  puts "Penalty Analytics:"
  puts "  Total penalties: #{analytics['total_count']}"
  puts "  Total points issued: #{analytics['total_points']}"
  puts "  Average points per penalty: #{analytics['average_points']}"
end

# Rule performance
response = client.get('/api/v1/analytics/rule_performance')
if response[:success]
  analytics = response[:body]['data']
  puts "Rule Performance:"
  puts "  Total processed: #{analytics['total_processed']}"
  puts "  Success rate: #{analytics['success_rate']}%"
  puts "  Most triggered rules: #{analytics['rule_trigger_frequency'].first(3).to_h}"
end

# Example 8: Manual User Suspension
puts "\n8. Manual User Operations"

# Create a new user for manual operations
manual_user_data = {
  user: {
    username: 'manual_test_user',
    email: 'manual@example.com',
    first_name: 'Manual',
    last_name: 'Test'
  }
}

response = client.post('/api/v1/users', manual_user_data)
if response[:success]
  manual_user = response[:body]['data']
  puts "✓ Created user for manual operations: #{manual_user['username']}"
  
  # Manually suspend user
  suspension_data = {
    duration: 7,
    reason: 'Manual suspension for testing'
  }
  
  response = client.post("/api/v1/users/#{manual_user['id']}/suspend", suspension_data)
  if response[:success]
    puts "✓ Manually suspended user for 7 days"
    puts "  Message: #{response[:body]['data']['message']}"
  end
  
  # Unsuspend user
  response = client.post("/api/v1/users/#{manual_user['id']}/unsuspend", {})
  if response[:success]
    puts "✓ Unsuspended user"
    puts "  Message: #{response[:body]['data']['message']}"
  end
end

puts "\n=== API Usage Examples Completed ==="
puts "\nKey Takeaways:"
puts "• Rules automatically process violations based on type and severity"
puts "• Repeat offenders trigger escalated penalties"
puts "• System provides comprehensive analytics and monitoring"
puts "• Manual overrides are available when needed"
puts "• All actions are logged and auditable"

puts "\nNext Steps:"
puts "• Explore the API documentation in README.md"
puts "• Try creating custom rules using the DSL"
puts "• Monitor rule performance using analytics endpoints"
puts "• Integrate with your existing user management system"
