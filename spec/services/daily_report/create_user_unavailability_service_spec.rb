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

RSpec.describe DailyReport::CreateUserUnavailabilityService do
  let(:ausbilder) { create(:user, global_permissions: %i[manage_daily_report_entries]) }
  let(:participant) { create(:user) }

  describe "#call" do
    it "writes an immutable initial revision and enqueues a schedule refresh" do
      service = described_class.new(user: ausbilder)
      result = nil

      expect do
        result = service.call(
          target_user: participant,
          kind: "krank",
          start_date: Date.new(2026, 10, 14),
          end_date: Date.new(2026, 10, 14),
          weekdays: []
        )
      end.to have_enqueued_job(DailyReport::RescheduleUserWorkPackagesJob).with(participant.id, ausbilder.id)

      expect(result).to be_success
      expect(result.result.revisions.pluck(:event, :revision_number)).to eq([["created", 1]])
    end

    it "refuses a participant acting on another participant's calendar" do
      result = described_class.new(user: participant).call(
        target_user: create(:user),
        kind: "urlaub",
        start_date: Date.new(2026, 10, 14),
        end_date: Date.new(2026, 10, 14),
        weekdays: []
      )

      expect(result).to be_failure
      expect(DailyReport::UserUnavailability.count).to eq(0)
    end
  end
end
