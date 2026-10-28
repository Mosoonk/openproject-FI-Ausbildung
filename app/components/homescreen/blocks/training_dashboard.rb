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

module Homescreen
  module Blocks
    class TrainingDashboard < Grids::WidgetComponent
      def render?
        TrainingDashboardQuery.allowed?(current_user)
      end

      def dashboard
        @dashboard ||= TrainingDashboardQuery.new(user: current_user)
      end

      def metric_value(key, value)
        return "—" if value.nil?

        key == :progress ? "#{value}%" : value
      end

      def deadline_label(participant)
        I18n.t("home_dashboard.days_overdue", count: (dashboard.today - participant.earliest_due_date).to_i)
      end

      def participant_work_packages_path(participant)
        helpers.work_packages_path(query_props: dashboard.participant_query_props(participant).to_json)
      end

      def overdue_work_packages_path(participant = nil)
        helpers.work_packages_path(
          query_props: dashboard.overdue_query_props(participant).to_json,
          name: :overdue
        )
      end
    end
  end
end
