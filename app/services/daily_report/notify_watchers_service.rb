# frozen_string_literal: true

module DailyReport
  class NotifyWatchersService
    def call(entry:, actor:, event:)
      recipients(entry).where.not(id: actor.id).find_each do |recipient|
        notify(recipient:, entry:, actor:, event:)
      end
    end

    private

    def recipients(entry)
      User
        .watcher_recipients(entry.work_package)
        .or(daily_report_recipients(entry.work_package))
        .distinct
    end

    def daily_report_recipients(work_package)
      User
        .allowed(:view_work_packages, work_package.project)
        .where(
          id: NotificationSetting
                .applicable(work_package.project)
                .where(daily_report: true)
                .select(:user_id)
        )
    end

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
