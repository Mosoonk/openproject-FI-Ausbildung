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
  class CreateEntryService
    def initialize(user:)
      @user = user
    end

    def call(work_package:, entry_date:, entry_kind: "report", status_type: nil, yesterday_text: nil, today_text: nil, issue_text: nil, risks_text: nil) # rubocop:disable Metrics/AbcSize, Layout/LineLength
      return ServiceResult.failure(errors: { base: :error_unauthorized }) unless policy(work_package).create?

      entry = build_entry(
        work_package:, entry_date:, entry_kind:, status_type:, yesterday_text:, today_text:, issue_text:, risks_text:
      )
      if entry.entry_date.present? && entry.entry_date < 7.days.ago.to_date
        entry.errors.add(:entry_date, :too_old)
        return ServiceResult.failure(result: entry, errors: entry.errors)
      end

      ApplicationRecord.transaction do
        entry.save!
        create_revision(entry)
        create_audit_event(entry)
      end

      NotifyWatchersJob.perform_later(entry.id, user.id, "created")

      ServiceResult.success(result: entry)
    rescue ActiveRecord::RecordInvalid => e
      ServiceResult.failure(result: entry, errors: e.record.errors)
    rescue ActiveRecord::RecordNotUnique
      entry.errors.add(:author_user_id, :taken)
      ServiceResult.failure(result: entry, errors: entry.errors)
    end

    private

    attr_reader :user

    def policy(work_package)
      EntryPolicy.new(user:, work_package:)
    end

    def build_entry(work_package:, **attributes)
      WorkPackageEntry.new(**attributes, work_package:, author: user, updated_by: user)
    end

    def create_revision(entry)
      entry.revisions.create!(
        revision_number: 1,
        event: "created",
        actor: user,
        yesterday_text: entry.yesterday_text,
        today_text: entry.today_text,
        issue_text: entry.issue_text,
        risks_text: entry.risks_text
      )
    end

    def create_audit_event(entry)
      entry.audit_events.create!(
        work_package: entry.work_package,
        author: entry.author,
        actor: user,
        event: "created"
      )
    end
  end
end
