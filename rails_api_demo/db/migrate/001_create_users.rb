class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.integer :status, default: 0, null: false
      
      # Suspension fields
      t.datetime :suspended_at
      t.datetime :suspension_expires_at
      t.text :suspension_reason
      
      t.timestamps
    end
    
    add_index :users, :username, unique: true
    add_index :users, :email, unique: true
    add_index :users, :status
    add_index :users, :suspended_at
  end
end
