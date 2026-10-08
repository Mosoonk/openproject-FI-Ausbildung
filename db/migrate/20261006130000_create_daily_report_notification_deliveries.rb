# frozen_string_literal: true

class CreateDailyReportNotificationDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_report_notification_deliveries do |t|
      t.references :work_package_entry,
                   null: false,
                   foreign_key: { to_table: :daily_report_work_package_entries }
      t.references :recipient_user, null: false, foreign_key: { to_table: :users }
      t.references :notification, foreign_key: true
      t.string :event, null: false
      t.timestamps

      t.index %i[work_package_entry_id recipient_user_id event],
              unique: true,
              name: "index_daily_report_notification_deliveries_unique"
    end
  end
end
