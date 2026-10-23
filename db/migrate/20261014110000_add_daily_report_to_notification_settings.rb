# frozen_string_literal: true

class AddDailyReportToNotificationSettings < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:notification_settings, :daily_report)
      add_column :notification_settings, :daily_report, :boolean, default: false, null: false
    end

    unless index_exists?(:notification_settings, :daily_report)
      add_index :notification_settings, :daily_report
    end
  end
end
