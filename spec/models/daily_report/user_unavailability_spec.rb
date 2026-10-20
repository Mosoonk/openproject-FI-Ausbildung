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

require "rails_helper"

RSpec.describe DailyReport::UserUnavailability do
  subject(:unavailability) { build(:daily_report_user_unavailability) }

  it { is_expected.to be_valid }

  describe "Berufsschule" do
    subject(:unavailability) do
      build(
        :daily_report_user_unavailability,
        :berufsschule,
        start_date: Date.new(2026, 10, 1),
        end_date: Date.new(2026, 10, 31)
      )
    end

    it "is unavailable on selected weekdays in its period" do
      expect(unavailability.unavailable_on?(Date.new(2026, 10, 14))).to be(true)
      expect(unavailability.unavailable_on?(Date.new(2026, 10, 15))).to be(false)
      expect(unavailability.unavailable_on?(Date.new(2026, 9, 30))).to be(false)
    end

    it "requires at least one weekday" do
      unavailability.weekdays = []

      expect(unavailability).to be_invalid
      expect(unavailability.errors[:weekdays]).to include("can't be blank.")
    end

    it "normalizes browser checkbox values" do
      unavailability.weekdays = ["", "1", "2", "5"]

      expect(unavailability).to be_valid
      expect(unavailability.weekdays).to eq([1, 2, 5])
    end
  end

  describe "Urlaub and Krank" do
    it "make every day in the inclusive range unavailable" do
      unavailability.assign_attributes(start_date: Date.new(2026, 10, 12), end_date: Date.new(2026, 10, 16))

      expect(unavailability.unavailable_on?(Date.new(2026, 10, 12))).to be(true)
      expect(unavailability.unavailable_on?(Date.new(2026, 10, 16))).to be(true)
    end

    it "rejects weekdays" do
      unavailability.weekdays = [1]

      expect(unavailability).to be_invalid
      expect(unavailability.errors[:weekdays]).to be_present
    end
  end

  it "rejects an end date before its start date" do
    unavailability.assign_attributes(start_date: Date.new(2026, 10, 16), end_date: Date.new(2026, 10, 12))

    expect(unavailability).to be_invalid
    expect(unavailability.errors[:end_date]).to be_present
  end
end
