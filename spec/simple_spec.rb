require 'spec_helper'

RSpec.describe 'Rule Engine Simple Tests' do
  describe 'ViolationContext' do
    it 'creates a context with correct attributes' do
      context = RuleEngine::ViolationContext.new(
        type: :fraud,
        severity: 8,
        user_id: 123,
        metadata: { source: 'test' }
      )
      
      expect(context.type).to eq(:fraud)
      expect(context.severity).to eq(8)
      expect(context.user_id).to eq(123)
      expect(context.metadata).to eq({ source: 'test' })
      expect(context.timestamp).to be_a(Time)
      expect(context.id).not_to be_nil
    end
  end

  describe 'Rule' do
    it 'creates and evaluates a rule correctly' do
      rule = RuleEngine::Rule.new(
        name: 'test_rule',
        priority: 50,
        condition: ->(context) { context.severity >= 5 },
        outcomes: [->(context) { RuleEngine::AddPenalty.new(context, points: 10) }]
      )
      
      expect(rule.name).to eq('test_rule')
      expect(rule.priority).to eq(50)
      expect(rule.enabled?).to be true
      
      # Test evaluation
      high_context = RuleEngine::ViolationContext.new(type: :test, severity: 8, user_id: 1)
      low_context = RuleEngine::ViolationContext.new(type: :test, severity: 3, user_id: 2)
      
      outcomes = rule.evaluate(high_context, strategy: :collect_all, collected: [])
      expect(outcomes.size).to eq(1)
      expect(outcomes.first).to be_a(RuleEngine::AddPenalty)
      
      outcomes = rule.evaluate(low_context, strategy: :collect_all, collected: [])
      expect(outcomes.size).to eq(0)
    end
  end

  describe 'RuleSet' do
    it 'creates and evaluates a rule set' do
      rule1 = RuleEngine::Rule.new(
        name: 'rule1',
        priority: 10,
        condition: ->(context) { context.severity >= 5 },
        outcomes: [->(context) { RuleEngine::AddPenalty.new(context, points: 10) }]
      )
      
      rule2 = RuleEngine::Rule.new(
        name: 'rule2',
        priority: 20,
        condition: ->(context) { context.severity >= 8 },
        outcomes: [->(context) { RuleEngine::SuspendAccount.new(context) }]
      )
      
      rule_set = RuleEngine::RuleSet.new(
        name: 'test_rules',
        rules: [rule1, rule2],
        strategy: :collect_all
      )
      
      expect(rule_set.name).to eq('test_rules')
      expect(rule_set.size).to eq(2)
      
      # Test evaluation
      context = RuleEngine::ViolationContext.new(type: :test, severity: 9, user_id: 1)
      outcomes = rule_set.evaluate(context)
      
      expect(outcomes.size).to eq(2)
      expect(outcomes.map(&:class)).to include(RuleEngine::AddPenalty, RuleEngine::SuspendAccount)
    end
  end

  describe 'RuleEngine' do
    it 'evaluates rules correctly' do
      rule = RuleEngine::Rule.new(
        name: 'test_rule',
        condition: ->(context) { context.severity >= 5 },
        outcomes: [->(context) { RuleEngine::AddPenalty.new(context, points: 10) }]
      )
      
      rule_set = RuleEngine::RuleSet.new(
        name: 'test_rules',
        rules: [rule]
      )
      
      engine = RuleEngine::RuleEngine.new(rule_sets: { 'test_rules' => rule_set })
      
      context = RuleEngine::ViolationContext.new(type: :test, severity: 8, user_id: 1)
      outcomes = engine.evaluate('test_rules', context)
      
      expect(outcomes.size).to eq(1)
      expect(outcomes.first).to be_a(RuleEngine::AddPenalty)
    end
    
    it 'raises error for unknown rule set' do
      engine = RuleEngine::RuleEngine.new
      context = RuleEngine::ViolationContext.new(type: :test, severity: 8, user_id: 1)
      
      expect {
        engine.evaluate('unknown_rules', context)
      }.to raise_error(RuleEngine::RuleSetNotFoundError)
    end
  end

  describe 'ActionHandler' do
    it 'can handle appropriate outcomes' do
      handler = RuleEngine::PenaltyHandler.new
      outcome = RuleEngine::AddPenalty.new(nil, points: 10)
      
      expect(handler.can_handle?(outcome)).to be true
    end
    
    it 'cannot handle inappropriate outcomes' do
      handler = RuleEngine::PenaltyHandler.new
      outcome = RuleEngine::SuspendAccount.new(nil)
      
      expect(handler.can_handle?(outcome)).to be false
    end
  end

  describe 'EventDispatcher' do
    it 'registers and dispatches to handlers' do
      dispatcher = RuleEngine::EventDispatcher.new
      handler = RuleEngine::PenaltyHandler.new
      outcome = RuleEngine::AddPenalty.new(nil, points: 10)
      
      dispatcher.register_handler(handler)
      expect(dispatcher.handler_count).to eq(1)
      
      results = dispatcher.dispatch([outcome])
      expect(results.size).to eq(1)
      expect(results.first[:handler]).to eq(handler)
      expect(results.first[:outcome]).to eq(outcome)
    end
  end
end
