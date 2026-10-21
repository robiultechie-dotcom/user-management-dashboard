class AddJobPositionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :job_position, :string
  end
end
