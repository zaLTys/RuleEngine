require 'securerandom'

module RuleEngine
  # Manages transactions for rule execution
  # Ensures that rules that need to be applied under a single transaction scope are handled properly
  class TransactionManager
    attr_reader :active_transactions

    def initialize
      @active_transactions = {}
    end

    def execute_in_transaction(transaction_id = nil, &block)
      transaction_id ||= SecureRandom.uuid
      
      if @active_transactions.key?(transaction_id)
        # Transaction already exists, execute within it
        yield
      else
        # Start new transaction
        begin
          @active_transactions[transaction_id] = {
            id: transaction_id,
            started_at: Time.now,
            outcomes: [],
            errors: []
          }
          
          result = yield
          
          # Commit transaction
          commit_transaction(transaction_id)
          result
        rescue => e
          # Rollback transaction
          rollback_transaction(transaction_id, e)
          raise TransactionError, "Transaction #{transaction_id} failed: #{e.message}"
        ensure
          @active_transactions.delete(transaction_id)
        end
      end
    end

    def add_outcome_to_transaction(transaction_id, outcome)
      return unless @active_transactions.key?(transaction_id)
      
      @active_transactions[transaction_id][:outcomes] << outcome
    end

    def add_error_to_transaction(transaction_id, error)
      return unless @active_transactions.key?(transaction_id)
      
      @active_transactions[transaction_id][:errors] << {
        message: error.message,
        backtrace: error.backtrace,
        timestamp: Time.now
      }
    end

    def transaction_outcomes(transaction_id)
      @active_transactions.dig(transaction_id, :outcomes) || []
    end

    def transaction_errors(transaction_id)
      @active_transactions.dig(transaction_id, :errors) || []
    end

    def transaction_active?(transaction_id)
      @active_transactions.key?(transaction_id)
    end

    def active_transaction_count
      @active_transactions.size
    end

    def clear_all_transactions
      @active_transactions.clear
    end

    private

    def commit_transaction(transaction_id)
      transaction = @active_transactions[transaction_id]
      return unless transaction

      puts "Committing transaction #{transaction_id} with #{transaction[:outcomes].size} outcomes"
      
      # Here you would implement actual commit logic
      # e.g., persist outcomes to database, send notifications, etc.
    end

    def rollback_transaction(transaction_id, error)
      transaction = @active_transactions[transaction_id]
      return unless transaction

      puts "ERROR: Rolling back transaction #{transaction_id} due to error: #{error.message}"
      
      # Here you would implement actual rollback logic
      # e.g., revert database changes, cancel notifications, etc.
    end
  end
end

