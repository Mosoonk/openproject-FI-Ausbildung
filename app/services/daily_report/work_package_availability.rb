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
  class WorkPackageAvailability
    def self.unavailabilities_for(work_package)
      new(work_package).unavailabilities
    end

    def self.applicable?(work_package)
      new(work_package).applicable?
    end

    def initialize(work_package)
      @work_package = work_package
    end

    def unavailabilities
      return [] unless applicable?

      UserUnavailability.active.for_user(assignee).of_kinds(included_kinds).to_a
    end

    def applicable?
      !work_package.ignore_non_working_days && assignee.is_a?(User) &&
        !assignee.admin? && !assignee.allowed_globally?(:manage_daily_report_entries) &&
        EntryPolicy.new(user: assignee, work_package:).create?
    end

    private

    attr_reader :work_package

    def assignee
      work_package.assigned_to
    end

    def included_kinds
      work_package.daily_report_schedule_setting&.included_unavailability_kinds || UserUnavailability::KINDS
    end
  end
end
