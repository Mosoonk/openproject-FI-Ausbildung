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
  class PersonalWorkingDays < WorkPackages::Shared::WorkingDays
    def initialize(unavailabilities:)
      super()
      @unavailabilities = unavailabilities
    end

    private

    attr_reader :unavailabilities

    def working_specific_date?(date)
      super && unavailabilities.none? { |unavailability| unavailability.unavailable_on?(date) }
    end
  end
end
