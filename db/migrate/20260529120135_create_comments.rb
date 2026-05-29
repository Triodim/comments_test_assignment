# frozen_string_literal: true

class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.text       :body,     null: false
      t.references :user,     null: false, foreign_key: true
      t.string     :ancestry

      t.timestamps
    end

    add_index :comments, :ancestry
  end
end
