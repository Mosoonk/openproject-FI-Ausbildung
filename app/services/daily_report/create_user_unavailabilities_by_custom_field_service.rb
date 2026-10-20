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
  class CreateUserUnavailabilitiesByCustomFieldService
    def initialize(user:)
      @user = user
    end

    def call(custom_field:, value:, **attributes)
      target_users = target_users(custom_field, value)
      return target_users if target_users.is_a?(ServiceResult)

      unavailabilities = create_unavailabilities(target_users, attributes)
      schedule(target_users)
      ServiceResult.success(result: unavailabilities)
    rescue ActiveRecord::RecordInvalid => e
      ServiceResult.failure(result: unavailabilities, errors: e.record.errors)
    end

    private

    attr_reader :user

    def target_users(custom_field, value)
      normalized_value = custom_field.value_of(value)
      return ServiceResult.failure(errors: { value: :invalid }) if normalized_value.blank?

      users = matching_users(custom_field, normalized_value)
      return ServiceResult.failure(errors: { base: :not_found }) if users.empty?
      return ServiceResult.failure(errors: { base: :error_unauthorized }) unless users.all? { policy(it).manage? }

      users
    end

    def matching_users(custom_field, value)
      ids = CustomValue
              .where(custom_field:, customized_type: "Principal", value: value.to_s)
              .select(:customized_id)

      User.active.where(type: "User", id: ids).to_a
    end

    def policy(target_user)
      UserUnavailabilityPolicy.new(user:, target_user:)
    end

    def create_unavailabilities(target_users, attributes)
      ApplicationRecord.transaction do
        target_users.map do |target_user|
          unavailability = UserUnavailability.new(**attributes, user: target_user, created_by: user, updated_by: user)
          unavailability.save!
          create_revision(unavailability)
          unavailability
        end
      end
    end

    def schedule(target_users)
      target_users.each do |target_user|
        RescheduleUserWorkPackagesJob.perform_later(target_user.id, user.id)
      end
    end

    def create_revision(unavailability)
      unavailability.revisions.create!(
        revision_number: 1,
        event: "created",
        actor: user,
        kind: unavailability.kind,
        start_date: unavailability.start_date,
        end_date: unavailability.end_date,
        weekdays: unavailability.weekdays
      )
    end
  end
end
