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

class DailyReport::UserUnavailabilitiesController < ApplicationController
  layout "admin"

  authorization_checked! :index, :create, :create_by_custom_field, :destroy

  before_action :authorize_daily_report_management

  def index
    @year = (params[:year].presence || Date.current.year).to_i
    @participants = User.active.order(:lastname, :firstname)
    @user_custom_fields = UserCustomField.order(:name)
    @unavailabilities = DailyReport::UserUnavailability.active
                                                          .includes(:user)
                                                          .where("start_date <= ? AND end_date >= ?", year_end, year_start)
  end

  def create
    result = create_unavailability

    if result.success?
      redirect_to daily_report_user_unavailabilities_path, notice: t("daily_report.availability.created")
    else
      redirect_to daily_report_user_unavailabilities_path, alert: result.errors.full_messages.to_sentence
    end
  end

  def destroy
    result = delete_unavailability

    if result.success?
      redirect_to daily_report_user_unavailabilities_path, notice: t("daily_report.availability.deleted")
    else
      redirect_to daily_report_user_unavailabilities_path, alert: result.errors.full_messages.to_sentence
    end
  end

  def create_by_custom_field
    result = create_unavailabilities_by_custom_field

    if result.success?
      redirect_to daily_report_user_unavailabilities_path,
                  notice: t("daily_report.availability.created_for_users", count: result.result.size)
    else
      redirect_to daily_report_user_unavailabilities_path, alert: result.errors.full_messages.to_sentence
    end
  end

  private

  def authorize_daily_report_management
    return if current_user.admin? || current_user.allowed_globally?(:manage_daily_report_entries)

    render_403
  end

  def unavailability_params
    params.expect(
      daily_report_user_unavailability: %i[kind start_date end_date] + [{ weekdays: [] }]
    ).to_h.symbolize_keys
  end

  def year_start
    Date.new(@year, 1, 1)
  end

  def year_end
    Date.new(@year, 12, 31)
  end

  def create_unavailability
    target_user = User.active.find(params.expect(daily_report_user_unavailability: [:user_id])[:user_id])
    DailyReport::CreateUserUnavailabilityService.new(user: current_user).call(target_user:, **unavailability_params)
  end

  def create_unavailabilities_by_custom_field
    attributes = unavailability_params
    filter = params.expect(daily_report_user_unavailability: %i[user_custom_field_id custom_field_value])
    custom_field = UserCustomField.find(filter[:user_custom_field_id])

    DailyReport::CreateUserUnavailabilitiesByCustomFieldService.new(user: current_user).call(
      custom_field:,
      value: filter[:custom_field_value],
      **attributes
    )
  end

  def delete_unavailability
    unavailability = DailyReport::UserUnavailability.active.find(params.expect(:id))
    DailyReport::DeleteUserUnavailabilityService.new(user: current_user).call(
      unavailability:,
      lock_version: unavailability.lock_version
    )
  end
end
