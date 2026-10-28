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
  class TrainingDashboardSettingsController < ApplicationController
    layout "global"
    authorization_checked! :show, :update
    before_action :authorize_dashboard_settings

    def show; end

    def update
      return invalid_types unless valid_type_ids?

      Setting.training_dashboard_task_type_ids = task_type_ids
      flash[:notice] = t(:notice_successful_update)
      redirect_to training_dashboard_settings_path
    end

    private

    def authorize_dashboard_settings
      render_403 unless TrainingDashboardQuery.allowed?(current_user)
    end

    def task_type_ids
      @task_type_ids ||= params.expect(settings: [{ training_dashboard_task_type_ids: [] }])
        .fetch(:training_dashboard_task_type_ids) { raise ActionController::ParameterMissing, :training_dashboard_task_type_ids }
        .compact_blank.uniq
    end

    def valid_type_ids?
      (task_type_ids - Type.where(id: task_type_ids).pluck(:id).map(&:to_s)).empty?
    end

    def invalid_types
      flash.now[:error] = t("home_dashboard.invalid_types")
      render :show, status: :unprocessable_entity
    end
  end
end
