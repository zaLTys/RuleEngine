require_relative 'rule_engine/version'
require_relative 'rule_engine/violation_context'
require_relative 'rule_engine/outcome'
require_relative 'rule_engine/rule'
require_relative 'rule_engine/rule_set'
require_relative 'rule_engine/evaluation_strategy'
require_relative 'rule_engine/rule_engine'
require_relative 'rule_engine/action_handler'
require_relative 'rule_engine/event_dispatcher'
require_relative 'rule_engine/transaction_manager'
require_relative 'rule_engine/dsl'
require_relative 'rule_engine/configuration_loader'

module RuleEngine
  class Error < StandardError; end
  class RuleNotFoundError < Error; end
  class RuleSetNotFoundError < Error; end
  class InvalidRuleError < Error; end
  class TransactionError < Error; end
end


