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
  class AvailabilityCalendarComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    def initialize(year:, unavailabilities:)
      super()
      @year = year
      @unavailabilities = unavailabilities
    end

    def call
      classes = "users-non-working-times-calendar-view daily-report-availability-calendar"
      flex_layout(data: wrapper_data, classes:) do |calendar|
        calendar.with_row(classes: "op-fc-wrapper", data: { "users--non-working-times-target" => "calendar" })
      end
    end

    private

    attr_reader :year, :unavailabilities

    def wrapper_data
      {
        controller: "users--non-working-times",
        "users--non-working-times-events-value" => events.to_json,
        "users--non-working-times-year-value" => year,
        "users--non-working-times-locale-value" => I18n.locale,
        "users--non-working-times-start-of-week-value" => (Setting.start_of_week || 1) % 7,
        "users--non-working-times-working-days-value" => Setting.working_days.map { |day| day % 7 }.sort.to_json
      }
    end

    def events
      unavailabilities.flat_map do |unavailability|
        occurrences_for(unavailability).map { |start_date, end_date| event_for(unavailability, start_date, end_date) }
      end
    end

    def occurrences_for(unavailability)
      if unavailability.kind == "berufsschule"
        (unavailability.start_date..unavailability.end_date)
          .select { |date| unavailability.weekdays.include?(date.cwday) }
          .map { |date| [date, date] }
      else
        [[unavailability.start_date, unavailability.end_date]]
      end
    end

    def event_for(unavailability, start_date, end_date)
      {
        start: start_date.iso8601,
        end: (end_date + 1.day).iso8601,
        title: "#{unavailability.user.name}: #{I18n.t("daily_report.availability.kinds.#{unavailability.kind}")}",
        type: unavailability.kind
      }
    end
  end
end
