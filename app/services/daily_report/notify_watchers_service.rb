# frozen_string_literal: true

module DailyReport
  class NotifyWatchersService
    def call(entry:, actor:, event:)
      User.watcher_recipients(entry.work_package).where.not(id: actor.id).find_each do |recipient|
        notify(recipient:, entry:, actor:, event:)
      end
    end

    private

    def notify(recipient:, entry:, actor:, event:)
      ApplicationRecord.transaction do
        delivery = NotificationDelivery.create_or_find_by!(
          work_package_entry: entry,
          recipient:,
          event:
        )

        delivery.with_lock do
          next if delivery.notification_id.present?

          result = Notifications::CreateService.new(user: actor).call(
            recipient:,
            actor:,
            resource: entry.work_package,
            reason: :daily_report
          )
          raise ActiveRecord::RecordInvalid, result.result unless result.success?

          delivery.update!(notification: result.result)
        end
      end
    end
  end
end
