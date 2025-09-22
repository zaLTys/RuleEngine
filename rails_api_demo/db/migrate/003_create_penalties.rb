class CreatePenalties < ActiveRecord::Migration[7.0]
  def change
    create_table :penalties do |t|
      t.references :user, null: false, foreign_key: true
      t.references :violation, null: true, foreign_key: true
      t.integer :penalty_type, null: false
      t.integer :points, null: false
      t.text :reason, null: false
      t.datetime :expires_at
      t.json :metadata
      
      t.timestamps
    end
    
    add_index :penalties, :penalty_type
    add_index :penalties, :expires_at
    add_index :penalties, :created_at
    add_index :penalties, [:user_id, :created_at]
    add_index :penalties, [:user_id, :expires_at]
  end
end
