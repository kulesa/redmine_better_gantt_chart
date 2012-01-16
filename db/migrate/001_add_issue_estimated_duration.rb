class AddIssueEstimatedDuration < ActiveRecord::Migration
  def self.up
    add_column :issues, :estimated_duration, :integer
  end

  def self.down
    remove_column :issues, :estimated_duration
  end
end
