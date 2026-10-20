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
  class WorkPackageScheduleSetting < ApplicationRecord
    self.table_name = "daily_report_work_package_schedule_settings"

    belongs_to :work_package

    before_validation { self.excluded_unavailability_kinds ||= [] }

    validate :excluded_unavailability_kinds_are_valid

    def included_unavailability_kinds
      UserUnavailability::KINDS - excluded_unavailability_kinds
    end

    private

    def excluded_unavailability_kinds_are_valid
      return if excluded_unavailability_kinds.uniq == excluded_unavailability_kinds &&
                excluded_unavailability_kinds.all? { |kind| kind.in?(UserUnavailability::KINDS) }

      errors.add(:excluded_unavailability_kinds, :invalid)
    end
  end
end
