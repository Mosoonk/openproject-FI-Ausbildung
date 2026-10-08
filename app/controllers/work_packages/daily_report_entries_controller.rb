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

class WorkPackages::DailyReportEntriesController < ApplicationController
  authorization_checked! :index, :create, :update, :destroy, :restore
  accept_key_auth :index

  before_action :find_work_package
  before_action :find_entry, only: %i[update destroy restore]

  def index
    entries = accessible_entries.includes(revisions: :actor).order(entry_date: :desc)

    render json: entries.map { |entry| represent(entry) }
  end

  def create
    call = DailyReport::CreateEntryService.new(user: current_user).call(
      work_package: @work_package,
      **daily_report_entry_params
    )

    if call.success?
      render json: represent(call.result), status: :created
    elsif unauthorized_error?(call.errors)
      render json: { error: "forbidden" }, status: :forbidden
    else
      render json: { errors: call.errors.to_hash }, status: :unprocessable_entity
    end
  end

  def update
    call = DailyReport::UpdateEntryService.new(user: current_user).call(
      entry: @entry,
      **daily_report_entry_params
    )

    if call.success?
      render json: represent(call.result)
    elsif unauthorized_error?(call.errors)
      render json: { error: "forbidden" }, status: :forbidden
    else
      render json: { errors: call.errors.to_hash }, status: :unprocessable_entity
    end
  end

  def destroy
    call = DailyReport::DeleteEntryService.new(user: current_user).call(
      entry: @entry,
      lock_version: params[:lock_version],
      comment: params[:comment]
    )

    if call.success?
      head :no_content
    elsif unauthorized_error?(call.errors)
      render json: { error: "forbidden" }, status: :forbidden
    else
      render json: { errors: call.errors.to_hash }, status: :unprocessable_entity
    end
  end

  def restore
    call = DailyReport::RestoreEntryService.new(user: current_user).call(
      entry: @entry,
      lock_version: params.expect(:lock_version)
    )

    if call.success?
      render json: represent(call.result)
    elsif unauthorized_error?(call.errors)
      render json: { error: "forbidden" }, status: :forbidden
    else
      render json: { errors: call.errors.to_hash }, status: :unprocessable_entity
    end
  end

  private

  def find_work_package
    @work_package = WorkPackage.visible.find(params.expect(:work_package_id))
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def daily_report_entry_params
    # `expect` requires every listed scalar, while the issue and risk fields
    # are optional and update requests do not contain entry_date.
    params.require(:daily_report_entry).permit( # rubocop:disable Rails/StrongParametersExpect
      :entry_date,
      :entry_kind,
      :status_type,
      :lock_version,
      :comment,
      :yesterday_text,
      :today_text,
      :issue_text,
      :risks_text
    ).to_h.symbolize_keys
  end

  def find_entry
    @entry = accessible_entries(include_deleted: action_name == "restore").find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def accessible_entries(include_deleted: false)
    scope = DailyReport::WorkPackageEntry.where(work_package: @work_package)
    scope = scope.active unless include_deleted
    return scope if DailyReport::EntryPolicy.new(user: current_user, work_package: @work_package).correct?

    scope.where(author: current_user)
  end

  def represent(entry)
    entry.slice(
      :id, :entry_date, :entry_kind, :status_type, :yesterday_text,
      :today_text, :issue_text, :risks_text, :lock_version, :updated_at
    ).merge(
      api_relationships(entry),
      correction_history: correction_history(entry),
      can_correct: DailyReport::EntryPolicy.new(user: current_user, work_package: @work_package).correct?,
      can_delete: DailyReport::EntryPolicy.new(user: current_user, work_package: @work_package).delete?
    )
  end

  def api_relationships(entry)
    {
      author: { id: entry.author.id, name: entry.author.name },
      work_package: { id: entry.work_package.id, subject: entry.work_package.subject },
      project: { id: entry.work_package.project.id, name: entry.work_package.project.name }
    }
  end

  def correction_history(entry)
    revisions = entry.revisions.sort_by(&:revision_number)

    revisions.each_cons(2).filter_map do |previous, current|
      next unless current.event == "corrected" && current.comment.present?

      {
        revision_number: current.revision_number,
        comment: current.comment,
        actor: { id: current.actor.id, name: current.actor.name },
        created_at: current.created_at,
        changes: revision_changes(previous, current)
      }
    end
  end

  def revision_changes(previous, current)
    %i[yesterday_text today_text issue_text risks_text].filter_map do |field|
      before = previous.public_send(field)
      after = current.public_send(field)
      { field:, before:, after: } unless before == after
    end
  end

  def unauthorized_error?(errors)
    return errors.of_kind?(:base, :error_unauthorized) if errors.respond_to?(:of_kind?)

    Array(errors[:base]).include?(:error_unauthorized)
  end
end
