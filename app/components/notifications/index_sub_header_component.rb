# frozen_string_literal: true

# -- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2010-2024 the OpenProject GmbH
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

module Notifications
  class IndexSubHeaderComponent < ApplicationComponent
    include ApplicationHelper

    PAGE_SIZES = [10, 50, 100].freeze

    attr_reader :facet, :filter_type, :filter_name, :page_size

    def initialize(project: nil, facet: nil, filter_type: nil, filter_name: nil, page_size: nil, custom_filters: nil)
      super
      @project = project
      @facet = facet
      @filter_type = filter_type
      @filter_name = filter_name
      @page_size = PAGE_SIZES.include?(page_size.to_i) ? page_size.to_i : 100
      @custom_filters = custom_filters
    end

    def current_filters
      @current_filters ||= { filter: @filter_type, name: @filter_name, filters: @custom_filters, page_size: }.compact
    end

    def unread_notifications?
      unread_notifications_query.valid? && unread_notifications_query.results.any?
    end

    private

    def unread_notifications_query
      @unread_notifications_query ||= Queries::Notifications::NotificationQuery.new(user: User.current).tap do |query|
        query.where(:read_ian, "=", "f")

        case filter_type
        when "project"
          id = filter_name.to_i
          query.where(:project_id, "=", [id])
        when "reason"
          query.where(:reason, "=", [filter_name])
        end
      end
    end
  end
end
