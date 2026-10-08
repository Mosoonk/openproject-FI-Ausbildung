# frozen_string_literal: true

module DailyReport
  class RestoreEntryService
    def initialize(user:)
      @user = user
    end

    def call(entry:, lock_version:)
      return ServiceResult.failure(errors: { base: :error_unauthorized }) unless policy(entry).delete?

      entry.update!(lock_version:, deleted_at: nil, deleted_by: nil)
      entry.audit_events.create!(work_package: entry.work_package, author: entry.author, actor: user, event: "restored")
      ServiceResult.success(result: entry)
    rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordInvalid => e
      record = e.respond_to?(:record) ? e.record : entry
      ServiceResult.failure(result: record, errors: record.errors)
    end

    private

    attr_reader :user

    def policy(entry)
      EntryPolicy.new(user:, work_package: entry.work_package)
    end
  end
end
