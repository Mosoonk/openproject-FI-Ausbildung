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
  class UserUnavailabilityPolicy
    def initialize(user:, target_user:)
      @user = user
      @target_user = target_user
    end

    def read?
      manage?
    end

    def manage?
      user.is_a?(User) && user.active? && target_user.is_a?(User) && target_user.active? &&
        (user.admin? || user.allowed_globally?(:manage_daily_report_entries))
    end

    private

    attr_reader :user, :target_user
  end
end
