# frozen_string_literal: true

# -- copyright
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
# ++
#
module OpenProject
  module Common
    class SubmenuComponent < ApplicationComponent
      def initialize(sidebar_menu_items: nil, searchable: false, create_btn_options: nil, custom_filter_groups: [])
        super()
        @sidebar_menu_items = sidebar_menu_items
        @searchable = searchable
        @create_btn_options = create_btn_options
        @custom_filter_groups = custom_filter_groups
      end

      def render?
        @sidebar_menu_items.present?
      end

      def top_level_sidebar_menu_items
        @sidebar_menu_items
          .filter { |menu_item| menu_item.header.nil? }
      end

      def nested_sidebar_menu_items
        @sidebar_menu_items
          .filter { |menu_item| menu_item.header.present? && menu_item.children.any? }
          .excluding(*@custom_filter_groups)
      end

      def custom_filter_groups
        @custom_filter_groups
      end

      def custom_filter_name(menu_item)
        menu_item_query_params(menu_item.children.first)["filter"]
      end

      def custom_filter_value(menu_item)
        menu_item_query_params(menu_item)["name"]
      end

      def selected_custom_filter_values(filter_name)
        custom_filter_values(filter_name) || legacy_custom_filter_values(filter_name)
      end

      private

      def menu_item_query_params(menu_item)
        URI.decode_www_form(URI.parse(menu_item.href).query.to_s).to_h
      end

      def custom_filter_values(filter_name)
        return unless helpers.params[:filters].respond_to?(:to_unsafe_h)

        Array(helpers.params[:filters].to_unsafe_h[filter_name]).compact_blank.map(&:to_s)
      end

      def legacy_custom_filter_values(filter_name)
        return [] unless helpers.params[:filter] == filter_name

        Array(helpers.params[:name]).compact_blank.map(&:to_s)
      end
    end
  end
end
