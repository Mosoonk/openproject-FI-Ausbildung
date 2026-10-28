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

require "spec_helper"

RSpec.describe "Training dashboard type settings", :skip_csrf, type: :rails_request do
  shared_let(:registration_type) { create(:type, name: "Prüfungsanmeldung AP-T1") }
  shared_let(:task_type) { create(:type, name: "Aufgabe") }
  shared_let(:project_type) { create(:type, name: "Project") }
  shared_let(:milestone_type) { create(:type_milestone, name: "AP-T1") }

  shared_examples "dashboard settings access" do
    before { login_as(user) }

    it "offers every type and persists Aufgabe and Project as initial defaults" do
      get training_dashboard_settings_path

      expect(response).to have_http_status(:ok)
      settings = Capybara.string(response.body).find("section", id: "training-dashboard-settings")
      expect(settings).to have_checked_field("Aufgabe", exact: true)
      expect(settings).to have_checked_field("Project", exact: true)
      expect(settings).to have_unchecked_field("Prüfungsanmeldung AP-T1", exact: true)
      expect(settings).to have_unchecked_field("AP-T1", exact: true)
      expect(Setting.find_by!(name: "training_dashboard_task_type_ids").value)
        .to contain_exactly(task_type.id.to_s, project_type.id.to_s)
    end

    it "saves the shared selection, ignores unrelated settings and allows clearing all types" do
      initial_title = Setting.app_title
      patch training_dashboard_settings_path,
            params: { settings: { training_dashboard_task_type_ids: ["", registration_type.id.to_s, milestone_type.id.to_s],
                                  app_title: "Unauthorized unrelated change" } }

      expect(response).to redirect_to(training_dashboard_settings_path)
      Setting.clear_cache
      expect(Setting.training_dashboard_task_type_ids).to contain_exactly(registration_type.id.to_s, milestone_type.id.to_s)
      expect(Setting.app_title).to eq(initial_title)

      get training_dashboard_settings_path
      settings = Capybara.string(response.body)
      expect(settings).to have_checked_field("Prüfungsanmeldung AP-T1")
      expect(settings).to have_unchecked_field("Project", exact: true)

      patch training_dashboard_settings_path, params: { settings: { training_dashboard_task_type_ids: [""] } }

      expect(response).to redirect_to(training_dashboard_settings_path)
      Setting.clear_cache
      expect(Setting.training_dashboard_task_type_ids).to be_empty
      get training_dashboard_settings_path
      expect(Capybara.string(response.body)).to have_unchecked_field("Aufgabe", exact: true)
    end

    it "shows newly added types unchecked and preserves selected IDs after renaming" do
      get training_dashboard_settings_path
      task_type.update!(name: "Renamed task")
      create(:type, name: "Aufgabe")
      create(:type, name: "New training type")

      get training_dashboard_settings_path

      settings = Capybara.string(response.body)
      expect(settings).to have_checked_field("Renamed task")
      expect(settings).to have_unchecked_field("Aufgabe", exact: true)
      expect(settings).to have_unchecked_field("New training type")
    end

    it "rejects nonexistent type IDs without changing the selection" do
      previous_ids = Setting.training_dashboard_task_type_ids
      patch training_dashboard_settings_path,
            params: { settings: { training_dashboard_task_type_ids: [task_type.id.to_s, "99999999"] } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("One or more selected types no longer exist")
      expect(Setting.training_dashboard_task_type_ids).to eq(previous_ids)
    end

    it "rejects malformed settings without clearing the selection" do
      previous_ids = Setting.training_dashboard_task_type_ids
      patch training_dashboard_settings_path,
            params: { settings: { training_dashboard_task_type_ids: "invalid" } }

      expect(response).to have_http_status(:bad_request)
      expect(Setting.training_dashboard_task_type_ids).to eq(previous_ids)
    end

    it "links to the settings from the dashboard" do
      get home_path

      expect(Capybara.string(response.body)).to have_link("Configure task types", href: training_dashboard_settings_path)
    end
  end

  context "as an administrator" do
    let(:user) { create(:admin) }

    include_examples "dashboard settings access"

    it "also links from the existing work package settings" do
      get admin_settings_work_packages_general_path

      expect(Capybara.string(response.body)).to have_link("Configure task types", href: training_dashboard_settings_path)
    end
  end

  context "as an Ausbilder" do
    let(:user) { create(:user, global_permissions: [:manage_daily_report_entries]) }

    include_examples "dashboard settings access"

    it "still cannot access general administration settings" do
      get admin_settings_work_packages_general_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  context "as an ordinary user" do
    before { login_as(create(:user)) }

    it "cannot read or change dashboard settings" do
      get training_dashboard_settings_path
      expect(response).to have_http_status(:forbidden)

      patch training_dashboard_settings_path,
            params: { settings: { training_dashboard_task_type_ids: [registration_type.id.to_s] } }
      expect(response).to have_http_status(:forbidden)
      expect(Setting.training_dashboard_task_type_ids).to contain_exactly(task_type.id.to_s, project_type.id.to_s)
    end
  end

  context "as an anonymous visitor", with_settings: { login_required: false } do
    it "cannot read or change dashboard settings" do
      get training_dashboard_settings_path
      expect(response).not_to have_http_status(:ok)

      patch training_dashboard_settings_path,
            params: { settings: { training_dashboard_task_type_ids: [registration_type.id.to_s] } }
      expect(Setting.training_dashboard_task_type_ids).to contain_exactly(task_type.id.to_s, project_type.id.to_s)
    end
  end
end
