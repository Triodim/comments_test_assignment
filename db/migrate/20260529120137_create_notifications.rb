# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user,    null: false, foreign_key: true
      t.bigint     :actor_id, null: false
      t.references :comment, null: false, foreign_key: true
      t.boolean    :read,    null: false, default: false

      t.timestamps
    end

    add_foreign_key :notifications, :users, column: :actor_id
    add_index :notifications, %i[user_id read]
  end
end
