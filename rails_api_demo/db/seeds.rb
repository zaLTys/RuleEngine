# Create sample users
users = [
  { username: 'alice_smith', email: 'alice@example.com', first_name: 'Alice', last_name: 'Smith' },
  { username: 'bob_jones', email: 'bob@example.com', first_name: 'Bob', last_name: 'Jones' },
  { username: 'charlie_brown', email: 'charlie@example.com', first_name: 'Charlie', last_name: 'Brown' },
  { username: 'diana_prince', email: 'diana@example.com', first_name: 'Diana', last_name: 'Prince' },
  { username: 'eve_adams', email: 'eve@example.com', first_name: 'Eve', last_name: 'Adams' }
]

created_users = users.map do |user_data|
  User.create!(user_data)
end

puts "Created #{created_users.count} users"

# Create sample violations with different types and severities
violations = [
  # High severity fraud - should trigger suspension
  {
    user: created_users[0],
    violation_type: :fraud,
    severity: 9,
    description: 'Attempted to use stolen credit card information',
    reported_by: 'automated_system',
    source: 'payment_processor',
    metadata: { transaction_id: 'txn_12345', amount: 500.00 }
  },
  
  # Medium severity spam - should trigger penalty
  {
    user: created_users[1],
    violation_type: :spam,
    severity: 6,
    description: 'Posted promotional content in multiple forums',
    reported_by: 'moderator_jane',
    source: 'forum_reports',
    metadata: { post_count: 15, forums: ['tech', 'gaming', 'lifestyle'] }
  },
  
  # Harassment - should trigger suspension and action block
  {
    user: created_users[2],
    violation_type: :harassment,
    severity: 8,
    description: 'Sent threatening messages to multiple users',
    reported_by: 'user_reports',
    source: 'message_system',
    metadata: { message_count: 5, targets: [created_users[0].id, created_users[1].id] }
  },
  
  # Inappropriate content - moderate severity
  {
    user: created_users[3],
    violation_type: :inappropriate_content,
    severity: 5,
    description: 'Posted content that violates community guidelines',
    reported_by: 'content_moderator',
    source: 'content_review',
    metadata: { content_type: 'image', flagged_by: 3 }
  },
  
  # Low severity fraud - should only get small penalty
  {
    user: created_users[4],
    violation_type: :fraud,
    severity: 3,
    description: 'Minor discrepancy in profile information',
    reported_by: 'verification_system',
    source: 'profile_verification',
    metadata: { field: 'address', confidence: 0.7 }
  },
  
  # Multiple violations for repeat offender testing
  {
    user: created_users[1], # Bob already has one violation
    violation_type: :spam,
    severity: 7,
    description: 'Continued spamming after previous warning',
    reported_by: 'automated_detection',
    source: 'spam_filter',
    metadata: { previous_violations: 1, escalation: true }
  },
  
  {
    user: created_users[1], # Bob's third violation
    violation_type: :policy_violation,
    severity: 4,
    description: 'Violation of terms of service',
    reported_by: 'support_team',
    source: 'manual_review',
    metadata: { section: 'user_conduct', severity_escalated: false }
  }
]

created_violations = violations.map do |violation_data|
  Violation.create!(violation_data)
end

puts "Created #{created_violations.count} violations"

# Process some violations automatically to demonstrate the rule engine
puts "\nProcessing violations through rule engine..."

rule_engine_service = RuleEngineService.instance

created_violations.each_with_index do |violation, index|
  puts "\nProcessing violation #{index + 1}: #{violation.violation_type} (severity: #{violation.severity}) for user #{violation.user.username}"
  
  result = rule_engine_service.process_violation(violation)
  
  if result[:success]
    puts "  ✓ Processed successfully"
    puts "  → Outcomes: #{result[:outcomes].map { |o| o[:type] }.join(', ')}"
    puts "  → Applied: #{result[:outcomes_applied].count} actions"
  else
    puts "  ✗ Processing failed: #{result[:error]}"
  end
end

puts "\nSeed data creation completed!"
puts "\nSummary:"
puts "- Users: #{User.count}"
puts "- Violations: #{Violation.count}"
puts "- Processed violations: #{Violation.processed.count}"
puts "- Penalties: #{Penalty.count}"
puts "- Suspended users: #{User.suspended.count}"

puts "\nYou can now test the API endpoints!"
