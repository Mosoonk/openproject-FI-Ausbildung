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
  class UserUnavailabilityRevision < ApplicationRecord
    self.table_name = "daily_report_user_unavailability_revisions"

    belongs_to :user_unavailability,
               class_name: "DailyReport::UserUnavailability",
               inverse_of: :revisions
    belongs_to :actor, class_name: "User", foreign_key: :actor_user_id, inverse_of: false

    validates :revision_number, :event, :actor, :kind, :start_date, :end_date, presence: true
    validates :event, inclusion: { in: %w[created updated deleted] }
  end
end
