# frozen_string_literal: true

class AddFeedIndexToComments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :comments, %i[ancestry created_at id],
              order: { created_at: :desc, id: :desc },
              algorithm: :concurrently,
              name: 'index_comments_on_ancestry_created_at_id'
  end
end
