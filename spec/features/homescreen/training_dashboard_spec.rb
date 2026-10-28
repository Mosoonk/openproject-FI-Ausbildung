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

RSpec.describe "Training dashboard type configuration and navigation", :js do
  let(:task_type) { create(:type, name: "Aufgabe") }
  let(:project_type) { create(:type, name: "Project") }
  let(:registration_type) { create(:type, name: "Prüfungsanmeldung AP-T1") }
  let(:project) { create(:project, types: [task_type, project_type, registration_type]) }
  let(:user) do
    create(:user,
           global_permissions: [:manage_daily_report_entries],
           member_with_permissions: { project => [:view_work_packages] })
  end
  let(:participant_field) { create(:user_custom_field, :string, name: "Lehrjahr", admin_only: false) }
  let(:participant) { create_participant(firstname: "Overdue", lastname: "Participant") }
  let(:available) { create_participant(firstname: "Available", lastname: "Participant") }
  let(:table) { Pages::WorkPackagesTable.new }

  it "lets an Ausbilder change shared types and shows the updated participant lists" do
    create(:work_package, project:, type: registration_type, assigned_to: available)
    create(:work_package, project:, type: project_type, assigned_to: participant)
    login_as(user)

    visit home_path
    within "#training-unassigned-participants-box" do
      expect(page).to have_link(available.name)
      expect(page).to have_no_link(participant.name)
    end

    click_link "Configure task types"
    using_wait_time(15) do
      expect(page).to have_current_path(training_dashboard_settings_path)
      expect(page).to have_checked_field("Aufgabe", exact: true)
      expect(page).to have_checked_field("Project", exact: true)
      check "Prüfungsanmeldung AP-T1"
      uncheck "Project", exact: true
    end
    click_button "Save"
    expect(page).to have_text("Successful update.")
    expect(page).to have_checked_field("Prüfungsanmeldung AP-T1")
    expect(page).to have_unchecked_field("Project", exact: true)

    visit home_path
    within "#training-unassigned-participants-box" do
      expect(page).to have_no_link(available.name)
      expect(page).to have_link(participant.name)
    end
  end

  it "opens strictly overdue tasks for one participant and the complete history for an available participant" do
    oldest = create_task(assigned_to: participant, subject: "Oldest open task", due_date: 17.days.ago)
    recent = create_task(assigned_to: participant, type: project_type, subject: "Recent open project", due_date: 2.days.ago)
    create_task(assigned_to: participant, due_date: Date.current, subject: "Due today")
    create_task(assigned_to: participant, due_date: nil, subject: "No deadline")
    create_task(assigned_to: participant, due_date: 30.days.ago, status: create(:closed_status), subject: "Closed old task")
    create_task(assigned_to: participant, type: registration_type, due_date: 40.days.ago, subject: "Unselected type")
    closed = create_task(assigned_to: available, status: create(:closed_status), subject: "Available participant history")
    registration = create_task(assigned_to: available, type: registration_type, subject: "Available participant registration")
    create_task(due_date: 4.days.ago, subject: "Unassigned overdue task")
    login_as(user)

    visit home_path
    within "#training-deadlines-box" do
      expect(page).to have_link(participant.name, count: 1)
      expect(page).to have_no_link(available.name)
      expect(page).to have_text("17 days overdue")
      click_link participant.name
    end

    expect(page).to have_current_path(work_packages_path, ignore_query: true)
    table.expect_work_package_listed(oldest, recent)
    table.expect_work_package_count(2)
    table.expect_work_package_order(oldest.id, recent.id)

    visit home_path
    within "#training-unassigned-participants-box" do
      click_link available.name
    end
    table.expect_work_package_listed(closed, registration)
    table.expect_work_package_count(2)

    visit home_path
    click_link "Open all 3 overdue projects and tasks"
    table.expect_work_package_count(3)
    table.expect_work_package_listed(oldest, recent)
  end

  def create_participant(**attributes)
    create(:user,
           custom_field_values: { participant_field.id => "LJ_1" },
           member_with_permissions: { project => [:view_work_packages] },
           **attributes)
  end

  def create_task(**attributes)
    create(:work_package, project:, type: task_type, **attributes)
  end
end
