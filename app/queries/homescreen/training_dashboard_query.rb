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

module Homescreen
  class TrainingDashboardQuery
    attr_reader :today

    def self.allowed?(user)
      user.active? && (user.admin? || user.allowed_globally?(:manage_daily_report_entries))
    end

    def self.available_types
      Type.order(:position, :id)
    end

    def initialize(user:, today: Date.current)
      @user = user
      @today = today
    end

    def metrics
      @metrics ||= {
        tasks: tasks.count,
        progress: tasks.average(progress_column)&.round,
        overdue: open_tasks.where(due_date: ...today).count,
        due_soon: open_tasks.where(due_date: today..(today + 7)).count
      }
    end

    def deadlines
      return @deadlines if defined?(@deadlines)

      earliest_dates = overdue_tasks
        .group(:assigned_to_id)
        .select("assigned_to_id, MIN(due_date) AS earliest_due_date")

      @deadlines = participants
        .joins("INNER JOIN (#{earliest_dates.to_sql}) overdue ON overdue.assigned_to_id = users.id")
        .select("users.*, overdue.earliest_due_date")
        .order("overdue.earliest_due_date ASC", :id)
        .to_a
    end

    def participants_without_tasks
      return @participants_without_tasks if defined?(@participants_without_tasks)

      assigned_ids = open_tasks.where.not(assigned_to_id: nil).select(:assigned_to_id)

      @participants_without_tasks = participants
        .where.not(id: assigned_ids)
        .ordered_by_name
        .to_a
    end

    def participant_field_available?
      participant_field.present?
    end

    def participant_query_props(participant)
      { c: %w[id project type subject status assignee dueDate],
        f: [{ "n" => "assignee", "o" => "=", "v" => [participant.id.to_s] }] }
    end

    def overdue_query_props(participant = nil)
      WorkPackages::DefaultQueryGeneratorService.overdue_query.deep_merge(
        c: %w[id project type subject status assignee dueDate],
        t: "dueDate:asc,id:asc",
        f: [{ "n" => "type", "o" => "=", "v" => task_type_ids }] +
          (participant ? participant_query_props(participant).fetch(:f) : [])
      ) do |key, existing, replacement|
        key == :f ? existing + replacement : replacement
      end
    end

    def overdue_items_count
      @overdue_items_count ||= overdue_tasks.count
    end

    private

    attr_reader :user

    def visible_work_packages
      return WorkPackage.none unless self.class.allowed?(user)

      WorkPackage.visible(user).joins(:project).where(projects: { active: true })
    end

    def tasks
      visible_work_packages
        .joins(:status)
        .where(type_id: task_type_ids)
    end

    def open_tasks
      tasks.where(statuses: { is_closed: false })
    end

    def overdue_tasks
      open_tasks.where(due_date: ...today)
    end

    def progress_column
      if WorkPackage.status_based_mode?
        Arel.sql("COALESCE(statuses.default_done_ratio, work_packages.done_ratio)")
      else
        :done_ratio
      end
    end

    def task_type_ids
      @task_type_ids ||= Type.where(id: Setting.training_dashboard_task_type_ids).pluck(:id).map(&:to_s)
    end

    def participant_field
      return unless self.class.allowed?(user)
      return @participant_field if defined?(@participant_field)

      @participant_field = UserCustomField.visible(user).find_by(name: "Lehrjahr")
    end

    def participants
      return User.none unless participant_field

      participant_ids = CustomValue
        .where(customized_type: "Principal", custom_field: participant_field)
        .where.not(value: [nil, ""])
        .select(:customized_id)

      User.visible(user).active.where(admin: false, id: participant_ids)
    end
  end
end
