# frozen_string_literal: true

class AddDailyReportToNotificationSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :notification_settings, :daily_report, :boolean, default: false, null: false
    add_index :notification_settings, :daily_report
  end
end
