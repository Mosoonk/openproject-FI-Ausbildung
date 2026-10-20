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
  class DeleteUserUnavailabilityService
    def initialize(user:)
      @user = user
    end

    def call(unavailability:, lock_version:)
      return ServiceResult.failure(errors: { base: :error_unauthorized }) unless policy(unavailability.user).manage?

      mark_deleted(unavailability, lock_version)
      persist(unavailability)
      schedule(unavailability)
      ServiceResult.success(result: unavailability)
    rescue ActiveRecord::StaleObjectError
      unavailability.errors.add(:lock_version, :stale)
      ServiceResult.failure(result: unavailability, errors: unavailability.errors)
    rescue ActiveRecord::RecordInvalid => e
      ServiceResult.failure(result: unavailability, errors: e.record.errors)
    end

    private

    attr_reader :user

    def policy(target_user)
      UserUnavailabilityPolicy.new(user:, target_user:)
    end

    def create_revision(unavailability)
      unavailability.revisions.create!(
        revision_number: unavailability.revisions.maximum(:revision_number).to_i + 1,
        event: "deleted",
        actor: user,
        kind: unavailability.kind,
        start_date: unavailability.start_date,
        end_date: unavailability.end_date,
        weekdays: unavailability.weekdays
      )
    end

    def mark_deleted(unavailability, lock_version)
      unavailability.assign_attributes(lock_version:, deleted_at: Time.current, deleted_by: user)
    end

    def persist(unavailability)
      ApplicationRecord.transaction do
        unavailability.save!
        create_revision(unavailability)
      end
    end

    def schedule(unavailability)
      RescheduleUserWorkPackagesJob.perform_later(unavailability.user_id, user.id)
    end
  end
end
