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

RSpec.describe "Training dashboard on the home page", type: :rails_request do
  shared_let(:project) { create(:project) }
  shared_let(:task_type) { create(:type, name: "Aufgabe") }
  shared_let(:project_type) { create(:type, name: "Project") }
  shared_let(:participant_field) { create(:user_custom_field, :string, name: "Lehrjahr", admin_only: false) }
  shared_let(:participant) do
    create(:user,
           firstname: "Available", lastname: "Participant",
           custom_field_values: { participant_field.id => "LJ_1" },
           member_with_permissions: { project => [:view_work_packages] })
  end

  before { Setting.training_dashboard_task_type_ids = [task_type.id.to_s, project_type.id.to_s] }

  context "as an Ausbilder" do
    let(:user) do
      create(:user,
             global_permissions: [:manage_daily_report_entries],
             member_with_permissions: { project => [:view_work_packages] })
    end

    before { login_as(user) }

    it "renders native widgets and links to participant history with only an assignee filter" do
      create(:work_package, project:, type: task_type, assigned_to: participant, status: create(:closed_status))
      participant

      get home_path

      expect(response).to have_http_status(:ok)
      rendered = Capybara.string(response.body)
      expect(rendered).to have_css("#training-overview-box.widget-box_full-width")
      expect(rendered).to have_css("[data-test-selector='training-metric-tasks']", text: "1")
      link = rendered.find("div", id: "training-unassigned-participants-box").find_link(participant.name)
      expect(query_props(link).fetch("f")).to eq(
        [{ "n" => "assignee", "o" => "=", "v" => [participant.id.to_s] }]
      )
      expect(rendered).to have_text("No participants with overdue open tasks")
      expect(rendered).to have_no_css("[data-test-selector='training-dashboard-view-all-overdue']")
    end

    it "links to the complete native list of overdue projects and tasks" do
      create(:work_package, project:, type: project_type, subject: "Overdue project", due_date: 3.days.ago)
      create(:work_package, project:, type: task_type, subject: "Overdue task", due_date: 2.days.ago)

      get home_path

      rendered = Capybara.string(response.body)
      link = rendered.find_link("Open all 2 overdue projects and tasks")
      uri = URI.parse(link[:href])
      query = Rack::Utils.parse_query(uri.query)
      props = JSON.parse(query.fetch("query_props"))

      expect(uri.path).to eq(work_packages_path)
      expect(query.fetch("name")).to eq("overdue")
      expect(props.fetch("f")).to include(
        { "n" => "dueDate", "o" => "<t-", "v" => ["1"] },
        { "n" => "status", "o" => "o", "v" => [] }
      )
      expect(props.fetch("c")).to include("project", "type", "subject", "dueDate")
    end

    it "shows each overdue participant once with the earliest date, days overdue and native filters" do
      create(:work_package, project:, type: task_type, assigned_to: participant, due_date: 17.days.ago)
      create(:work_package, project:, type: task_type, assigned_to: participant, due_date: 2.days.ago)

      get home_path

      rendered = Capybara.string(response.body)
      deadlines = rendered.find("div", id: "training-deadlines-box")
      expect(deadlines).to have_link(participant.name, count: 1)
      expect(deadlines).to have_text("17 days overdue")
      expect(deadlines).to have_text(I18n.l(Date.current - 17, format: :default))
      expect(query_props(deadlines.find_link(participant.name)).fetch("f")).to contain_exactly(
        { "n" => "assignee", "o" => "=", "v" => [participant.id.to_s] },
        { "n" => "status", "o" => "o", "v" => [] },
        { "n" => "dueDate", "o" => "<t-", "v" => ["1"] },
        { "n" => "type", "o" => "=", "v" => [task_type.id.to_s, project_type.id.to_s] }
      )
      expect(rendered.find("div", id: "training-unassigned-participants-box")).to have_no_link(participant.name)
    end

    it "renders German translations" do
      user.update!(language: "de")
      create(:work_package, project:, type: task_type, assigned_to: participant, due_date: 1.day.ago)

      get home_path

      expect(response.body).to include("Ausbildungsübersicht", "1 Tag überfällig", "Teilnehmer ohne offene Aufgaben")
      expect(response.body).not_to include("translation missing")
    end

    it "does not leak hidden tasks or users into the home page" do
      hidden_project = create(:project, public: false)
      create(:work_package, project: hidden_project, subject: "Hidden training task", due_date: Date.current)
      create(:user, firstname: "Secret", lastname: "Participant", custom_field_values: { participant_field.id => "LJ_1" })

      get home_path

      expect(response.body).not_to include("Hidden training task", "Secret Participant")
    end
  end

  it "renders the dashboard for an administrator" do
    login_as(create(:admin))

    get home_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="training-overview-box"')
  end

  it "does not render or query the dashboard for an ordinary participant" do
    login_as(participant)
    allow(Homescreen::TrainingDashboardQuery).to receive(:new).and_call_original

    get home_path

    expect(response).to have_http_status(:ok)
    expect(Homescreen::TrainingDashboardQuery).not_to have_received(:new)
    expect(response.body).not_to include(
      'id="training-overview-box"',
      'id="training-deadlines-box"',
      'id="training-unassigned-participants-box"'
    )
  end

  it "does not render the dashboard for an anonymous visitor", with_settings: { login_required: false } do
    get home_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('id="training-overview-box"')
  end

  def query_props(link)
    uri = URI.parse(link[:href])
    expect(uri.path).to eq(work_packages_path)
    JSON.parse(Rack::Utils.parse_query(uri.query).fetch("query_props"))
  end
end
