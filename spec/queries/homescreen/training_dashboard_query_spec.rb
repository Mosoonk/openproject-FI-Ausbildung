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

RSpec.describe Homescreen::TrainingDashboardQuery do
  subject(:dashboard) { described_class.new(user:, today:) }

  shared_let(:task_type) { create(:type, name: "Aufgabe") }
  shared_let(:project_type) { create(:type, name: "Project") }
  shared_let(:other_type) { create(:type, name: "Prüfungsanmeldung AP-T1") }
  shared_let(:project) { create(:project, types: [task_type, project_type, other_type]) }
  shared_let(:user) do
    create(:user,
           global_permissions: [:manage_daily_report_entries],
           member_with_permissions: { project => [:view_work_packages] })
  end
  let(:participant_field) { create(:user_custom_field, :string, name: "Lehrjahr", admin_only: false) }
  let(:today) { Date.current }

  current_user { user }

  before { Setting.training_dashboard_task_type_ids = [task_type.id.to_s, project_type.id.to_s] }

  describe "metrics", with_settings: { work_package_done_ratio: "field" } do
    it "counts selected tasks and known progress, including today and the seventh day in upcoming dates" do
      create_task(due_date: today - 1, done_ratio: 20)
      create_task(due_date: today, done_ratio: 40)
      create_task(due_date: today + 7, done_ratio: nil)
      create_task(due_date: today + 8, done_ratio: 80)
      create_task(due_date: today - 2, done_ratio: 100, status: create(:closed_status))
      create_task(type: other_type, due_date: today - 3, done_ratio: 100)

      expect(dashboard.metrics).to eq(tasks: 5, progress: 60, overdue: 1, due_soon: 2)
    end

    it "counts selected parent and Project work packages" do
      parent = create_task(type: project_type)
      create_task(parent:)

      expect(dashboard.metrics[:tasks]).to eq(2)
    end

    it "allows milestones to be selected and Project types to be deselected" do
      milestone_type = create(:type_milestone)
      create_task(type: project_type)
      create_task(type: milestone_type)
      Setting.training_dashboard_task_type_ids = [milestone_type.id.to_s]

      expect(dashboard.metrics[:tasks]).to eq(1)
    end

    it "excludes inaccessible and archived projects" do
      hidden_project = create(:project, public: false)
      archived_project = create(:project, public: true)
      create_task(project: hidden_project, done_ratio: 100, due_date: today - 1)
      create_task(project: archived_project, done_ratio: 100, due_date: today - 1)
      archived_project.update_column(:active, false)
      create_task(done_ratio: 20)

      expect(dashboard.metrics).to eq(tasks: 1, progress: 20, overdue: 0, due_soon: 0)
      expect(dashboard.overdue_items_count).to be_zero
    end

    it "leaves unknown progress blank" do
      create_task(done_ratio: nil)

      expect(dashboard.metrics[:progress]).to be_nil
    end

    it "handles no selected types without falling back to defaults" do
      participant = create_participant
      create_task(assigned_to: participant, due_date: today - 1)
      Setting.training_dashboard_task_type_ids = []

      expect(dashboard.metrics).to eq(tasks: 0, progress: nil, overdue: 0, due_soon: 0)
      expect(dashboard.deadlines).to be_empty
      expect(dashboard.participants_without_tasks).to eq([participant])
    end

    it "keeps selecting types by ID after they are renamed" do
      create_task(done_ratio: 20)
      task_type.update!(name: "Renamed task")

      expect(dashboard.metrics[:tasks]).to eq(1)
    end
  end

  it "uses native status-based progress", with_settings: { work_package_done_ratio: "status" } do
    work_package = create_task(status: create(:status, default_done_ratio: 70))
    work_package.update_column(:done_ratio, 10)

    expect(dashboard.metrics[:progress]).to eq(70)
  end

  describe "participants without open tasks" do
    it "lists each participant with no tasks, only closed tasks or only unselected types once" do
      unassigned = create_participant
      finished = create_participant
      other = create_participant
      2.times { create_task(assigned_to: finished, status: create(:closed_status)) }
      2.times { create_task(assigned_to: other, type: other_type) }

      expect(dashboard.participants_without_tasks).to contain_exactly(unassigned, finished, other)
    end

    it "does not list a participant who also has one open selected task" do
      participant = create_participant
      create_task(assigned_to: participant, status: create(:closed_status, name: "Open but closed"))
      create_task(assigned_to: participant, type: other_type)
      create_task(assigned_to: participant, status: create(:status, name: "Done but open", is_closed: false))

      expect(dashboard.participants_without_tasks).to be_empty
    end

    it "counts selected Project parents and changes availability when Project is deselected" do
      participant = create_participant
      parent = create_task(assigned_to: participant, type: project_type)
      create_task(parent:)

      expect(dashboard.participants_without_tasks).to be_empty

      Setting.training_dashboard_task_type_ids = [task_type.id.to_s]
      expect(described_class.new(user:).participants_without_tasks).to eq([participant])
    end

    it "only counts direct assignments, consistently with the native assignee filter" do
      participant = create_participant
      create_task(assigned_to: create(:group, members: [participant]))

      expect(dashboard.participants_without_tasks).to eq([participant])
    end

    it "does not infer assignments from hidden work packages" do
      participant = create_participant
      create_task(project: create(:project, public: false), assigned_to: participant)

      expect(dashboard.participants_without_tasks).to eq([participant])
    end

    it "excludes users without Lehrjahr, locked users, administrators and invisible users" do
      participant = create_participant
      create_participant(admin: true)
      create_participant(status: User.statuses[:locked])
      create_participant(member_with_permissions: {})
      create(:user, member_with_permissions: { project => [:view_work_packages] })

      expect(dashboard.participants_without_tasks).to eq([participant])
    end
  end

  describe "deadlines" do
    it "lists participants once, ordered by their oldest open selected deadline" do
      oldest = create_participant
      recent = create_participant
      create_task(assigned_to: recent, due_date: today - 2)
      create_task(assigned_to: oldest, type: project_type, due_date: today - 17)
      create_task(assigned_to: oldest, due_date: today - 3)
      create_task(assigned_to: oldest, due_date: today - 40, status: create(:closed_status))
      create_task(assigned_to: recent, type: other_type, due_date: today - 50)

      expect(dashboard.deadlines.map(&:id)).to eq([oldest.id, recent.id])
      expect(dashboard.deadlines.map(&:earliest_due_date)).to eq([today - 17, today - 2])
      expect(dashboard.overdue_items_count).to eq(3)
    end

    it "ignores today, future dates, missing dates, closed tasks and unselected types" do
      participant = create_participant
      [today, today + 1, nil].each { |due_date| create_task(assigned_to: participant, due_date:) }
      create_task(assigned_to: participant, due_date: today - 1, status: create(:closed_status))
      create_task(assigned_to: participant, due_date: today - 1, type: other_type)

      expect(dashboard.deadlines).to be_empty
      expect(dashboard.overdue_items_count).to be_zero
    end

    it "does not disclose hidden dates or invisible participants" do
      participant = create_participant
      invisible_participant = create_participant(member_with_permissions: {})
      create_task(assigned_to: participant, due_date: today - 2)
      create_task(project: create(:project, public: false), assigned_to: participant, due_date: today - 100)
      create_task(assigned_to: invisible_participant, due_date: today - 30)

      expect(dashboard.deadlines.map(&:id)).to eq([participant.id])
      expect(dashboard.deadlines.first.earliest_due_date).to eq(today - 2)
    end

    it "uses a bounded query count to load names and dates for many participants" do
      10.times { create_task(assigned_to: create_participant, due_date: today - 1) }
      dashboard.participant_field_available?
      dashboard.metrics

      expect do
        dashboard.deadlines.each { |participant| [participant.name, participant.earliest_due_date] }
      end.to have_a_query_limit(3)
      expect(dashboard.deadlines.size).to eq(10)
    end
  end

  describe "native work package navigation" do
    it "links to overdue tasks using internal type and assignee IDs" do
      participant = create_participant
      filters = dashboard.overdue_query_props(participant).fetch(:f)

      expect(filters).to contain_exactly(
        { "n" => "dueDate", "o" => "<t-", "v" => ["1"] },
        { "n" => "status", "o" => "o", "v" => [] },
        { "n" => "type", "o" => "=", "v" => [task_type.id.to_s, project_type.id.to_s] },
        { "n" => "assignee", "o" => "=", "v" => [participant.id.to_s] }
      )
    end

    it "links to the full participant history using only the assignee filter" do
      participant = create_participant

      expect(dashboard.participant_query_props(participant).fetch(:f)).to eq(
        [{ "n" => "assignee", "o" => "=", "v" => [participant.id.to_s] }]
      )
    end
  end

  describe "authorization and missing participant fields" do
    it "allows administrators" do
      admin = create(:admin)
      create_task

      expect(described_class.allowed?(admin)).to be true
      expect(described_class.new(user: admin).metrics[:tasks]).to eq(1)
    end

    it "returns no data to ordinary participants" do
      participant = create_participant
      create_task(assigned_to: participant, due_date: today - 1)
      restricted = described_class.new(user: participant)

      expect(described_class.allowed?(participant)).to be false
      expect(restricted.metrics[:tasks]).to eq(0)
      expect(restricted.deadlines).to be_empty
      expect(restricted.participants_without_tasks).to be_empty
    end

    it "rejects anonymous and locked viewers" do
      expect(described_class.allowed?(User.anonymous)).to be false
      user.update!(status: User.statuses[:locked])
      expect(described_class.allowed?(user)).to be false
    end

    it "does not expose an admin-only Lehrjahr field" do
      create_task(assigned_to: create_participant, due_date: today - 1)
      participant_field.update!(admin_only: true)

      expect(dashboard).not_to be_participant_field_available
      expect(dashboard.participants_without_tasks).to be_empty
      expect(dashboard.deadlines).to be_empty
    end

    it "handles installations without Lehrjahr" do
      expect(dashboard).not_to be_participant_field_available
      expect(dashboard.participants_without_tasks).to be_empty
      expect(dashboard.deadlines).to be_empty
    end
  end

  def create_task(**attributes)
    create(:work_package, project:, type: task_type, **attributes)
  end

  def create_participant(**attributes)
    create(:user,
           custom_field_values: { participant_field.id => "LJ_1" },
           member_with_permissions: { project => [:view_work_packages] },
           **attributes)
  end
end
