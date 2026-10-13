# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module DailyReport
  class UpdateEntryService
    def initialize(user:)
      @user = user
    end

    def call(entry:, lock_version:, comment:, yesterday_text: nil, today_text: nil, issue_text: nil, risks_text: nil) # rubocop:disable Metrics/AbcSize
      return ServiceResult.failure(errors: { base: :error_unauthorized }) unless policy(entry).correct?

      entry.assign_attributes(
        lock_version:,
        yesterday_text:,
        today_text:,
        issue_text:,
        risks_text:,
        updated_by: user
      )
      entry.errors.add(:comment, :blank) if comment.blank?
      return ServiceResult.failure(result: entry, errors: entry.errors) if entry.errors.any?

      ApplicationRecord.transaction do
        entry.save!
        create_revision(entry, comment)
        create_audit_event(entry, comment)
      end

      NotifyWatchersJob.perform_later(entry.id, user.id, "corrected")

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

    def create_revision(entry, comment)
      entry.revisions.create!(
        revision_number: entry.revisions.maximum(:revision_number).to_i + 1,
        event: "corrected",
        comment:,
        actor: user,
        yesterday_text: entry.yesterday_text,
        today_text: entry.today_text,
        issue_text: entry.issue_text,
        risks_text: entry.risks_text
      )
    end

    def create_audit_event(entry, comment)
      entry.audit_events.create!(
        work_package: entry.work_package,
        author: entry.author,
        actor: user,
        event: "corrected",
        comment:
      )
    end
  end
end
