# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

module DailyReport
  class DeleteEntryService
    def initialize(user:)
      @user = user
    end

    def call(entry:, lock_version:, comment:) # rubocop:disable Metrics/AbcSize
      return ServiceResult.failure(errors: { base: :error_unauthorized }) unless policy(entry).delete?

      if comment.blank?
        entry.errors.add(:comment, :blank)
        return ServiceResult.failure(result: entry, errors: entry.errors)
      end

      entry.assign_attributes(lock_version:, deleted_at: Time.current, deleted_by: user)

      ApplicationRecord.transaction do
        entry.save!
        create_audit_event(entry, comment)
      end

      NotifyWatchersJob.perform_later(entry.id, user.id, "deleted")

      ServiceResult.success(result: entry)
    rescue ActiveRecord::StaleObjectError
      entry.errors.add(:lock_version, :stale)
      ServiceResult.failure(result: entry, errors: entry.errors)
    rescue ActiveRecord::RecordInvalid => e
      ServiceResult.failure(result: entry, errors: e.record.errors)
    end

    private

    attr_reader :user

    def policy(entry)
      EntryPolicy.new(user:, work_package: entry.work_package)
    end

    def create_audit_event(entry, comment)
      entry.audit_events.create!(
        work_package: entry.work_package,
        author: entry.author,
        actor: user,
        event: "deleted",
        comment:
      )
    end
  end
end
