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

require "spec_helper"

RSpec.describe "Notifications",
               :skip_csrf,
               type: :rails_request do
  shared_let(:user) { create(:user) }

  before do
    login_as user
  end

  describe "GET /notifications" do
    context "with filters present" do
      it "renders the facet switch with the current filters (Regression #56916)" do
        get notifications_path(filter: "reason", name: "mentioned")

        expect(response).to have_http_status(:ok)

        expect(page).to have_link("Show all") { |link|
          link["href"] == notifications_path(facet: "all", filter: "reason", name: "mentioned", page_size: 100)
        }
      end

      it "renders a custom user attribute filter with multiple values" do
        custom_field = create(:user_custom_field, :string, name: "Lehrjahr")
        filters = { "actor_cf_#{custom_field.id}" => %w[LJ_1 LJ_2] }

        get notifications_path(filters:)

        expect(response).to have_http_status(:ok)

        sidebar_src = page.find("turbo-frame#notifications_sidemenu")["src"]
        expect(Rack::Utils.parse_nested_query(URI(sidebar_src).query)).to include("filters" => filters)
      end

      it "rejects an unknown custom user attribute filter" do
        get notifications_path(filters: { "actor_cf_999999" => ["LJ_1"] })

        expect(response).to redirect_to(notifications_path)
      end
    end
  end

  describe "GET /notifications/menu" do
    it "renders the menu with a reason filter" do
      get notifications_menu_path(filter: "reason", name: "mentioned")

      expect(response).to have_http_status(:ok)
    end

    it "renders the menu with multiple custom user attribute values" do
      get notifications_menu_path(filters: { "actor_cf_1" => %w[LJ_1 LJ_2] })

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /notifications/mark_all_read" do
    it "accepts a reason filter without custom user attributes" do
      post mark_all_read_notifications_path(filter: "reason", name: "mentioned")

      expect(response).to have_http_status(:redirect)
    end
  end
end
