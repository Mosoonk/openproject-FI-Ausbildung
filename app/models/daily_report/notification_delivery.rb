# frozen_string_literal: true

module DailyReport
  class NotificationDelivery < ApplicationRecord
    self.table_name = "daily_report_notification_deliveries"

    belongs_to :work_package_entry, class_name: "DailyReport::WorkPackageEntry"
    belongs_to :recipient, class_name: "User", foreign_key: :recipient_user_id, inverse_of: false
    belongs_to :notification, optional: true

    validates :event, presence: true
  end
end
