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

FactoryBot.define do
  factory :daily_report_user_unavailability, class: "DailyReport::UserUnavailability" do
    user
    association :created_by, factory: :admin
    association :updated_by, factory: :admin
    kind { "urlaub" }
    start_date { Date.new(2026, 10, 12) }
    end_date { start_date }
    weekdays { [] }

    trait :berufsschule do
      kind { "berufsschule" }
      weekdays { [3] }
    end
  end
end
