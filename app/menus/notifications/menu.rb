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

module Notifications
  class Menu < Submenu
    ENTERPRISE_REASONS = %w[shared].freeze

    include Rails.application.routes.url_helpers

    attr_reader :params, :current_user,
                :query, :unread, :unread_by_reason, :unread_by_project,
                :unread_by_actor_custom_field

    def initialize(params:, current_user:)
      @params = params
      @current_user = current_user
      @unread = filter_unread
      @unread_by_reason = filter_unread_by_reason
      @unread_by_project = filter_unread_by_project
      @unread_by_actor_custom_field = filter_unread_by_actor_custom_field

      super(view_type: nil, project: nil, params:)
    end

    def menu_items
      menu_groups = [
        OpenProject::Menu::MenuGroup.new(header: nil, children: [inbox_menu]),
        OpenProject::Menu::MenuGroup.new(header: I18n.t("notifications.menu.by_reason"),
                                         children: reason_filters),
        OpenProject::Menu::MenuGroup.new(header: I18n.t("notifications.menu.by_project"),
                                         children: project_filters)
      ]

      menu_groups.concat(custom_field_menu_groups)
    end

    def custom_field_menu_groups
      @custom_field_menu_groups ||= actor_custom_field_filters
    end

    private

    def inbox_menu
      count = unread
      menu_item(title: I18n.t("notifications.menu.inbox"), icon_key: :inbox, count: count == 0 ? nil : count)
    end

    def reason_filters
      %w[mentioned assigned responsible watched daily_report dateAlert reminder shared].map do |reason|
        count = unread_by_reason[reason]
        menu_item(title: I18n.t("notifications.reasons.#{reason}"),
                  icon_key: reason,
                  count: count == 0 ? nil : count,
                  query_params: query_params("reason", reason),
                  show_enterprise_icon: lacking_ee_permission?(reason))
      end
    end

    def project_filters
      unread_by_project.map do |project, count|
        menu_item(title: (project.parent.present? ? "... " : "") + project.name,
                  count:,
                  query_params: query_params("project", project.id))
      end
    end

    def base_query
      Queries::Notifications::NotificationQuery.new(user: current_user)
                                               .where(:read_ian, "=", "f")
    end

    def filter_unread
      query = base_query
      query.results.count
    end

    def filter_unread_by_reason
      query = base_query
      query.group(:reason)
      query.group_values
    end

    def filter_unread_by_project
      query = base_query
      query.group(:project)
      query.group_values
    end

    def filter_unread_by_actor_custom_field
      custom_fields = UserCustomField.visible(current_user).order(:name).to_a
      return {} if custom_fields.empty?

      group_custom_field_counts(custom_fields, unread_custom_field_value_counts(custom_fields))
    end

    def unread_custom_field_value_counts(custom_fields)
      unread_notifications
        .joins(actor_custom_field_join)
        .where(CustomValue.table_name => { custom_field_id: custom_fields.map(&:id) })
        .where.not(CustomValue.table_name => { value: [nil, ""] })
        .group("#{CustomValue.table_name}.custom_field_id", "#{CustomValue.table_name}.value")
        .count
    end

    def unread_notifications
      Notification.visible(current_user).recipient(current_user).where(read_ian: false)
    end

    def actor_custom_field_join
      <<~SQL.squish
        INNER JOIN #{CustomValue.table_name}
          ON #{CustomValue.table_name}.customized_type = 'Principal'
          AND #{CustomValue.table_name}.customized_id = #{Notification.table_name}.actor_id
      SQL
    end

    def group_custom_field_counts(custom_fields, counts)
      fields_by_id = custom_fields.index_by(&:id)
      counts.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |((field_id, value), count), result|
        custom_field = fields_by_id[field_id]
        result[custom_field][value] = count if custom_field
      end
    end

    def actor_custom_field_filters
      unread_by_actor_custom_field.map do |custom_field, values|
        children = values
                     .sort_by { |value, _| formatted_custom_field_value(custom_field, value).downcase }
                     .map do |value, count|
          filter = Queries::Notifications::Filters::ActorCustomFieldFilter.filter_name(custom_field)
          menu_item(title: formatted_custom_field_value(custom_field, value),
                    count:,
                    query_params: query_params(filter, value),
                    selected: actor_custom_field_value_selected?(custom_field, value))
        end

        OpenProject::Menu::MenuGroup.new(
          header: custom_field.name,
          children:
        )
      end
    end

    def formatted_custom_field_value(custom_field, value)
      CustomValue.new(custom_field:, value:).formatted_value
    end

    def query_params(filter, name)
      { filter:, name: }
    end

    def actor_custom_field_value_selected?(custom_field, value)
      filter = Queries::Notifications::Filters::ActorCustomFieldFilter.filter_name(custom_field)
      selected_actor_custom_field_values(filter).include?(value.to_s)
    end

    def selected_actor_custom_field_values(filter)
      return [] unless params[:filter] == filter

      Array(params[:name]).compact_blank.map(&:to_s)
    end

    def selected?(query_params)
      params[:filter] == query_params[:filter] && params[:name] == (query_params[:name] ? query_params[:name].to_s : nil)
    end

    def query_path(query_params)
      return notifications_share_upsell_path(query_params) if lacking_ee_permission?(query_params[:name])

      notifications_center_path(query_params)
    end

    def icon_map
      {
        "mentioned" => :mention,
        "assigned" => :"op-person-assigned",
        "responsible" => :"op-person-accountable",
        "watched" => :eye,
        "daily_report" => :file,
        "shared" => :"share-android",
        "dateAlert" => :"op-calendar-alert",
        "reminder" => :"op-alarm"
      }
    end

    def lacking_ee_permission?(reason)
      reason == "shared" && !EnterpriseToken.allows_to?(:work_package_sharing)
    end
  end
end
