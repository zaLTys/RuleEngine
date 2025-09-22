class CreateViolations < ActiveRecord::Migration[7.0]
  def change
    create_table :violations do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :violation_type, null: false
      t.integer :severity, null: false
      t.text :description, null: false
      t.integer :status, default: 0, null: false
      t.string :reported_by
      t.string :source
      t.json :metadata
      
      # Processing fields
      t.datetime :processed_at
      t.json :processing_result
      
      t.timestamps
    end
    
    add_index :violations, :violation_type
    add_index :violations, :severity
    add_index :violations, :status
    add_index :violations, :created_at
    add_index :violations, :processed_at
    add_index :violations, [:user_id, :created_at]
  end
end
