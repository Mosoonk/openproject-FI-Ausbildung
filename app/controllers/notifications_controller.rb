# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class NotificationsController < ApplicationController
  include WorkPackages::WithSplitView

  before_action :require_login
  before_action :filtered_query, only: :mark_all_read
  no_authorization_required! :index, :split_view, :update_counter, :mark_all_read, :share_upsell

  before_action :validate_query, only: %i[index]

  def index
    render_notifications_layout
  end

  def split_view
    respond_to do |format|
      format.html do
        if turbo_frame_request?
          render "work_packages/split_view", layout: false
        else
          render :index, layout: "notifications"
        end
      end
    end
  end

  def mark_all_read
    if filtered_query.valid?
      filtered_query.results.update_all(read_ian: true, updated_at: Time.zone.now)
    else
      flash[:error] = filtered_query.errors.full_messages.join(", ")
    end

    redirect_back_or_to(notifications_path)
  end

  def share_upsell
    render_notifications_layout
  end

  private

  def split_view_base_route = notifications_path(request.query_parameters)

  def render_notifications_layout
    # Frontend will handle rendering
    # but we will need to render with notification specific layout
    render layout: "notifications"
  end

  def filtered_query
    @filtered_query ||= Queries::Notifications::NotificationQuery
                         .new(user: current_user)
                         .where(:read_ian, "=", "f")
                         .tap { apply_filter(it) }
  end

  def apply_filter(query)
    apply_legacy_filter(query)
    custom_attribute_filters.each { |filter, values| query.where(filter, "=", values) }
  end

  def apply_legacy_filter(query)
    case params[:filter]
    when "project"
      query.where(:project_id, "=", [params[:name].to_i])
    when "reason"
      query.where(:reason, "=", [params[:name]])
    when actor_custom_field_filter?
      query.where(params[:filter], "=", actor_custom_field_values)
    end
  end

  def actor_custom_field_values
    Array(params[:name]).compact_blank
  end

  def custom_attribute_filters
    raw_custom_attribute_filters.filter_map do |filter, values|
      values = Array(values).compact_blank
      [filter, values] if actor_custom_field_filter?(filter) && values.present?
    end
  end

  def validate_query
    return unless notification_filter_present?
    return if valid_notification_filter? && filtered_query.valid?

    flash[:error] = I18n.t("notifications.query.invalid_filter")
    redirect_to notifications_path
  end

  def notification_filter_present?
    params[:filter].present? || params[:filters].present?
  end

  def valid_notification_filter?
    valid_legacy_filter? && valid_custom_attribute_filters?
  end

  def valid_legacy_filter?
    params[:filter].blank? || params.expect(:filter).in?(%w[project reason]) || actor_custom_field_filter?
  end

  def valid_custom_attribute_filters?
    raw_custom_attribute_filters.all? do |filter, values|
      actor_custom_field_filter?(filter) && Array(values).compact_blank.present?
    end
  end

  def raw_custom_attribute_filters
    params.permit(filters: {}).fetch(:filters, {}).to_h
  end

  def actor_custom_field_filter?(filter = params[:filter])
    field_id = filter.to_s.match(/\Aactor_cf_(\d+)\z/)&.captures&.first
    field_id.present? && UserCustomField.visible(current_user).exists?(id: field_id)
  end
end
