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
  class EntryPolicy
    def initialize(user:, work_package:)
      @user = user
      @work_package = work_package
    end

    def create?
      active_user? && visible? && directly_or_group_assigned?
    end

    def correct?
      active_user? && visible? && elevated?
    end

    def delete?
      active_user? && visible? && user.admin?
    end

    private

    attr_reader :user, :work_package

    def active_user?
      user.is_a?(User) && user.active?
    end

    def visible?
      WorkPackage.visible(user).exists?(id: work_package.id)
    end

    def directly_or_group_assigned?
      return true if work_package.assigned_to_id == user.id

      user.groups.exists?(id: work_package.assigned_to_id)
    end

    def elevated?
      user.admin? || user.allowed_globally?(:manage_daily_report_entries)
    end
  end
end
