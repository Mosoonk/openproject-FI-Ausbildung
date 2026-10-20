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
  class CreateUserUnavailabilityService
    def initialize(user:)
      @user = user
    end

    def call(target_user:, **attributes)
      return ServiceResult.failure(errors: { base: :error_unauthorized }) unless policy(target_user).manage?

      unavailability = UserUnavailability.new(**attributes, user: target_user, created_by: user, updated_by: user)
      persist(unavailability)
      schedule(target_user)
      ServiceResult.success(result: unavailability)
    rescue ActiveRecord::RecordInvalid => e
      ServiceResult.failure(result: unavailability, errors: e.record.errors)
    end

    private

    attr_reader :user

    def policy(target_user)
      UserUnavailabilityPolicy.new(user:, target_user:)
    end

    def create_revision(unavailability, event)
      unavailability.revisions.create!(
        revision_number: 1,
        event:,
        actor: user,
        kind: unavailability.kind,
        start_date: unavailability.start_date,
        end_date: unavailability.end_date,
        weekdays: unavailability.weekdays
      )
    end

    def persist(unavailability)
      ApplicationRecord.transaction do
        unavailability.save!
        create_revision(unavailability, "created")
      end
    end

    def schedule(target_user)
      RescheduleUserWorkPackagesJob.perform_later(target_user.id, user.id)
    end
  end
end
