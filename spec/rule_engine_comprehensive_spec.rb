require 'spec_helper'

RSpec.describe 'Rule Engine Comprehensive Tests' do
  let(:engine) { RuleEngine::RuleEngine.new }
  let(:penalty_handler) { RuleEngine::PenaltyHandler.new }
  let(:suspension_handler) { RuleEngine::AccountSuspensionHandler.new }
  let(:notification_handler) { RuleEngine::NotificationHandler.new }
  let(:logging_handler) { RuleEngine::LoggingHandler.new }

  before do
    engine.register_handlers(penalty_handler, suspension_handler, notification_handler, logging_handler)
  end

  describe 'Basic Rule Evaluation' do
    let(:fraud_rules) do
      RuleEngine::RuleSet.new(
        name: 'fraud_detection',
        rules: [
          RuleEngine::Rule.new(
            name: 'high_severity_fraud',
            priority: 100,
            condition: ->(context) { context.type == :fraud && context.severity >= 8 },
            outcomes: [
              ->(context) { RuleEngine::SuspendAccount.new(context, duration: 'indefinite', reason: 'High severity fraud') },
              ->(context) { RuleEngine::NotifySupport.new(context, priority: :high, message: 'High severity fraud detected') }
            ]
          ),
          RuleEngine::Rule.new(
            name: 'medium_severity_fraud',
            priority: 50,
            condition: ->(context) { context.type == :fraud && context.severity >= 5 && context.severity < 8 },
            outcomes: [
              ->(context) { RuleEngine::AddPenalty.new(context, points: 50, reason: 'Medium severity fraud') },
              ->(context) { RuleEngine::NotifySupport.new(context, priority: :medium, message: 'Medium severity fraud detected') }
            ]
          ),
          RuleEngine::Rule.new(
            name: 'low_severity_fraud',
            priority: 10,
            condition: ->(context) { context.type == :fraud && context.severity < 5 },
            outcomes: [
              ->(context) { RuleEngine::AddPenalty.new(context, points: 10, reason: 'Low severity fraud') }
            ]
          )
        ],
        strategy: :collect_all
      )
    end

    before do
      engine.add_rule_set(fraud_rules)
    end

    context 'High severity fraud' do
      let(:context) do
        RuleEngine::ViolationContext.new(
          type: :fraud,
          severity: 9,
          user_id: 123,
          metadata: { source: 'automated_detection' }
        )
      end

      it 'triggers suspension and notification' do
        result = engine.evaluate_and_dispatch('fraud_detection', context)
        
        expect(result[:outcomes]).to have(2).items
        expect(result[:outcomes].map(&:class)).to include(RuleEngine::SuspendAccount, RuleEngine::NotifySupport)
        
        suspend_outcome = result[:outcomes].find { |o| o.is_a?(RuleEngine::SuspendAccount) }
        expect(suspend_outcome.duration).to eq('indefinite')
        expect(suspend_outcome.reason).to eq('High severity fraud')
        
        notify_outcome = result[:outcomes].find { |o| o.is_a?(RuleEngine::NotifySupport) }
        expect(notify_outcome.priority).to eq(:high)
      end

      it 'executes all matching rules in collect_all strategy' do
        result = engine.evaluate('fraud_detection', context)
        expect(result).to have(2).items
      end
    end

    context 'Medium severity fraud' do
      let(:context) do
        RuleEngine::ViolationContext.new(
          type: :fraud,
          severity: 6,
          user_id: 124,
          metadata: { source: 'user_report' }
        )
      end

      it 'triggers penalty and notification' do
        result = engine.evaluate_and_dispatch('fraud_detection', context)
        
        expect(result[:outcomes]).to have(2).items
        expect(result[:outcomes].map(&:class)).to include(RuleEngine::AddPenalty, RuleEngine::NotifySupport)
        
        penalty_outcome = result[:outcomes].find { |o| o.is_a?(RuleEngine::AddPenalty) }
        expect(penalty_outcome.points).to eq(50)
        expect(penalty_outcome.reason).to eq('Medium severity fraud')
      end
    end

    context 'Low severity fraud' do
      let(:context) do
        RuleEngine::ViolationContext.new(
          type: :fraud,
          severity: 3,
          user_id: 125,
          metadata: { source: 'automated_detection' }
        )
      end

      it 'triggers only penalty' do
        result = engine.evaluate_and_dispatch('fraud_detection', context)
        
        expect(result[:outcomes]).to have(1).item
        expect(result[:outcomes].first).to be_a(RuleEngine::AddPenalty)
        expect(result[:outcomes].first.points).to eq(10)
      end
    end

    context 'Non-fraud violation' do
      let(:context) do
        RuleEngine::ViolationContext.new(
          type: :spam,
          severity: 8,
          user_id: 126
        )
      end

      it 'does not trigger any rules' do
        result = engine.evaluate_and_dispatch('fraud_detection', context)
        expect(result[:outcomes]).to be_empty
      end
    end
  end

  describe 'Different Evaluation Strategies' do
    let(:test_rules) do
      RuleEngine::RuleSet.new(
        name: 'test_strategies',
        rules: [
          RuleEngine::Rule.new(
            name: 'rule1',
            priority: 100,
            condition: ->(context) { context.severity >= 5 },
            outcomes: [->(context) { RuleEngine::AddPenalty.new(context, points: 10) }]
          ),
          RuleEngine::Rule.new(
            name: 'rule2',
            priority: 50,
            condition: ->(context) { context.severity >= 3 },
            outcomes: [->(context) { RuleEngine::LogViolation.new(context, level: :info) }]
          ),
          RuleEngine::Rule.new(
            name: 'rule3',
            priority: 10,
            condition: ->(context) { context.severity >= 1 },
            outcomes: [->(context) { RuleEngine::NotifyUser.new(context, message: 'Violation detected') }]
          )
        ],
        strategy: :collect_all
      )
    end

    before do
      engine.add_rule_set(test_rules)
    end

    context 'First match strategy' do
      let(:context) do
        RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
      end

      it 'stops at first matching rule' do
        result = engine.evaluate('test_strategies', context, strategy: :first_match)
        expect(result).to have(1).item
        expect(result.first).to be_a(RuleEngine::AddPenalty)
      end
    end

    context 'Collect all strategy' do
      let(:context) do
        RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
      end

      it 'collects all matching rules' do
        result = engine.evaluate('test_strategies', context, strategy: :collect_all)
        expect(result).to have(3).items
        expect(result.map(&:class)).to include(RuleEngine::AddPenalty, RuleEngine::LogViolation, RuleEngine::NotifyUser)
      end
    end
  end

  describe 'Transaction Support' do
    let(:transaction_rules) do
      RuleEngine::RuleSet.new(
        name: 'transaction_test',
        rules: [
          RuleEngine::Rule.new(
            name: 'transaction_rule',
            condition: ->(context) { context.severity >= 5 },
            outcomes: [
              ->(context) { RuleEngine::AddPenalty.new(context, points: 20) },
              ->(context) { RuleEngine::LogViolation.new(context, level: :warn) }
            ]
          )
        ]
      )
    end

    before do
      engine.add_rule_set(transaction_rules)
    end

    it 'executes rules within transaction scope' do
      context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
      transaction_id = "txn_#{Time.now.to_i}"
      
      result = engine.evaluate('transaction_test', context, transaction_id: transaction_id)
      
      expect(result).to have(2).items
      expect(engine.transaction_manager.transaction_active?(transaction_id)).to be false
    end

    it 'handles transaction errors' do
      context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
      transaction_id = "txn_#{Time.now.to_i}"
      
      # Mock a rule that raises an error
      allow_any_instance_of(RuleEngine::Rule).to receive(:evaluate).and_raise(StandardError, 'Transaction error')
      
      expect {
        engine.evaluate('transaction_test', context, transaction_id: transaction_id)
      }.to raise_error(RuleEngine::TransactionError)
    end
  end

  describe 'Rule Management' do
    let(:manageable_rules) do
      RuleEngine::RuleSet.new(
        name: 'manageable_rules',
        rules: [
          RuleEngine::Rule.new(
            name: 'rule1',
            condition: ->(context) { context.severity >= 5 },
            outcomes: [->(context) { RuleEngine::AddPenalty.new(context, points: 10) }]
          ),
          RuleEngine::Rule.new(
            name: 'rule2',
            condition: ->(context) { context.severity >= 3 },
            outcomes: [->(context) { RuleEngine::LogViolation.new(context) }]
          )
        ]
      )
    end

    before do
      engine.add_rule_set(manageable_rules)
    end

    it 'can disable and enable rules' do
      rule_set = engine.rule_set('manageable_rules')
      
      # Disable rule1
      rule_set.disable_rule('rule1')
      expect(rule_set.enabled_rules).to have(1).item
      expect(rule_set.disabled_rules).to have(1).item
      
      # Test with disabled rule
      context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
      result = engine.evaluate('manageable_rules', context)
      expect(result).to have(1).item # Only rule2 should fire
      
      # Re-enable rule1
      rule_set.enable_rule('rule1')
      result = engine.evaluate('manageable_rules', context)
      expect(result).to have(2).items # Both rules should fire
    end

    it 'can add and remove rules dynamically' do
      rule_set = engine.rule_set('manageable_rules')
      
      # Add new rule
      new_rule = RuleEngine::Rule.new(
        name: 'rule3',
        condition: ->(context) { context.severity >= 8 },
        outcomes: [->(context) { RuleEngine::SuspendAccount.new(context) }]
      )
      
      rule_set.add_rule(new_rule)
      expect(rule_set.size).to eq(3)
      
      # Remove rule
      rule_set.remove_rule('rule2')
      expect(rule_set.size).to eq(2)
    end
  end

  describe 'Configuration Loading' do
    it 'loads rules from YAML configuration' do
      # Create a temporary YAML file
      yaml_content = <<~YAML
        test_rules:
          strategy: collect_all
          rules:
            - name: "test_rule"
              priority: 50
              condition:
                type: field_greater_than
                field: severity
                value: 5
              outcomes:
                - type: add_penalty
                  points: 15
                  reason: "Test violation"
      YAML
      
      File.write('temp_rules.yaml', yaml_content)
      
      begin
        engine.load_from_config('temp_rules.yaml')
        
        context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
        result = engine.evaluate('test_rules', context)
        
        expect(result).to have(1).item
        expect(result.first).to be_a(RuleEngine::AddPenalty)
        expect(result.first.points).to eq(15)
      ensure
        File.delete('temp_rules.yaml')
      end
    end
  end

  describe 'Error Handling' do
    let(:error_rules) do
      RuleEngine::RuleSet.new(
        name: 'error_test',
        rules: [
          RuleEngine::Rule.new(
            name: 'error_rule',
            condition: ->(context) { raise StandardError, 'Rule evaluation error' },
            outcomes: [->(context) { RuleEngine::AddPenalty.new(context, points: 10) }]
          ),
          RuleEngine::Rule.new(
            name: 'working_rule',
            condition: ->(context) { context.severity >= 5 },
            outcomes: [->(context) { RuleEngine::LogViolation.new(context) }]
          )
        ]
      )
    end

    before do
      engine.add_rule_set(error_rules)
    end

    it 'continues evaluation after rule errors' do
      context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
      
      # Should not raise error, but continue with working rule
      result = engine.evaluate('error_test', context)
      expect(result).to have(1).item
      expect(result.first).to be_a(RuleEngine::LogViolation)
    end
  end

  describe 'Performance Tests' do
    let(:performance_rules) do
      rules = (1..100).map do |i|
        RuleEngine::Rule.new(
          name: "rule_#{i}",
          priority: i,
          condition: ->(context) { context.severity >= i },
          outcomes: [->(context) { RuleEngine::LogViolation.new(context, level: :info) }]
        )
      end
      
      RuleEngine::RuleSet.new(name: 'performance_test', rules: rules)
    end

    before do
      engine.add_rule_set(performance_rules)
    end

    it 'handles large number of rules efficiently' do
      context = RuleEngine::ViolationContext.new(type: :test, severity: 50, user_id: 1)
      
      start_time = Time.current
      result = engine.evaluate('performance_test', context)
      end_time = Time.current
      
      execution_time = (end_time - start_time) * 1000 # Convert to milliseconds
      
      expect(result).to have(50).items # Rules 1-50 should match
      expect(execution_time).to be < 1000 # Should complete in less than 1 second
    end
  end

  describe 'DSL Usage' do
    class TestProcessor
      include RuleEngine::DSL
      include RuleEngine::DSL::ConditionHelpers
    end

    let(:processor) { TestProcessor.new }

    it 'creates rules using DSL' do
      dsl_rules = processor.define_rule_set("dsl_test") do
        rule "dsl_rule", priority: 50 do
          when { |context| context.severity >= 5 }
          add_penalty points: 25, reason: "DSL rule violation"
          log_violation level: :warn
        end
      end

      engine.add_rule_set(dsl_rules)
      
      context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
      result = engine.evaluate('dsl_test', context)
      
      expect(result).to have(2).items
      expect(result.map(&:class)).to include(RuleEngine::AddPenalty, RuleEngine::LogViolation)
    end

    it 'uses condition helpers' do
      dsl_rules = processor.define_rule_set("helper_test") do
        rule "helper_rule", priority: 50 do
          when { |context| severity_at_least(5).call(context) && violation_type(:test).call(context) }
          add_penalty points: 30, reason: "Helper rule violation"
        end
      end

      engine.add_rule_set(dsl_rules)
      
      context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
      result = engine.evaluate('helper_test', context)
      
      expect(result).to have(1).item
      expect(result.first).to be_a(RuleEngine::AddPenalty)
    end
  end

  describe 'Action Handler Integration' do
    let(:handler_rules) do
      RuleEngine::RuleSet.new(
        name: 'handler_test',
        rules: [
          RuleEngine::Rule.new(
            name: 'penalty_rule',
            condition: ->(context) { context.severity >= 5 },
            outcomes: [->(context) { RuleEngine::AddPenalty.new(context, points: 20) }]
          ),
          RuleEngine::Rule.new(
            name: 'suspension_rule',
            condition: ->(context) { context.severity >= 8 },
            outcomes: [->(context) { RuleEngine::SuspendAccount.new(context, duration: '7 days') }]
          )
        ]
      )
    end

    before do
      engine.add_rule_set(handler_rules)
    end

    it 'dispatches outcomes to appropriate handlers' do
      context = RuleEngine::ViolationContext.new(type: :test, severity: 7, user_id: 1)
      result = engine.evaluate_and_dispatch('handler_test', context)
      
      expect(result[:outcomes]).to have(1).item
      expect(result[:dispatch_results]).to have(1).item
      
      dispatch_result = result[:dispatch_results].first
      expect(dispatch_result[:handler]).to eq(penalty_handler)
      expect(dispatch_result[:outcome]).to be_a(RuleEngine::AddPenalty)
    end

    it 'handles multiple outcomes' do
      context = RuleEngine::ViolationContext.new(type: :test, severity: 9, user_id: 1)
      result = engine.evaluate_and_dispatch('handler_test', context)
      
      expect(result[:outcomes]).to have(2).items
      expect(result[:dispatch_results]).to have(2).items
    end
  end
end

