# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "rails_helper"

RSpec.describe DailyReport::CreateUserUnavailabilitiesByCustomFieldService do
  let(:ausbilder) { create(:user, global_permissions: %i[manage_daily_report_entries]) }
  let(:custom_field) { create(:user_custom_field, :list, possible_values: %w[LJ_1 LJ_2]) }
  let(:first_participant) { create(:user) }
  let(:second_participant) { create(:user) }
  let(:other_participant) { create(:user) }

  before do
    create(
      :principal_custom_value,
      custom_field:,
      customized: first_participant,
      value: custom_field.value_of("LJ_1")
    )
    create(
      :principal_custom_value,
      custom_field:,
      customized: second_participant,
      value: custom_field.value_of("LJ_1")
    )
    create(
      :principal_custom_value,
      custom_field:,
      customized: other_participant,
      value: custom_field.value_of("LJ_2")
    )
  end

  it "creates an absence for every active user with the matching custom attribute" do
    result = described_class.new(user: ausbilder).call(
      custom_field:,
      value: "LJ_1",
      kind: "berufsschule",
      start_date: Date.new(2026, 9, 1),
      end_date: Date.new(2027, 7, 31),
      weekdays: [3]
    )

    expect(result).to be_success
    expect(result.result.map(&:user_id)).to contain_exactly(first_participant.id, second_participant.id)
    expect(DailyReport::UserUnavailability.where(user: other_participant)).to be_empty
    expect(result.result.flat_map(&:revisions).pluck(:event, :revision_number)).to all(eq(["created", 1]))
  end

  it "does not create records when the attribute value does not match a user" do
    result = described_class.new(user: ausbilder).call(
      custom_field:,
      value: "LJ_3",
      kind: "urlaub",
      start_date: Date.new(2026, 10, 12),
      end_date: Date.new(2026, 10, 16),
      weekdays: []
    )

    expect(result).to be_failure
    expect(DailyReport::UserUnavailability).to be_empty
  end
end
