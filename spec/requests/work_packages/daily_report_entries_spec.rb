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

RSpec.describe "Daily Report entries", :skip_csrf, type: :rails_request do
  shared_let(:project) { create(:project) }
  shared_let(:participant) do
    create(:user, member_with_permissions: { project => %i[view_work_packages] })
  end
  shared_let(:other_participant) do
    create(:user, member_with_permissions: { project => %i[view_work_packages] })
  end
  shared_let(:work_package) { create(:work_package, project:, assigned_to: participant) }
  shared_let(:own_entry) do
    create_entry(author: participant, yesterday_text: "own yesterday", today_text: "own today")
  end
  shared_let(:other_entry) do
    create_entry(author: other_participant, yesterday_text: "other yesterday", today_text: "other today")
  end

  before { login_as(participant) }

  describe "POST /work_packages/:work_package_id/daily_report_entries" do
    it "allows a participant to create an entry exactly seven days in the past" do
      expect do
        post work_package_daily_report_entries_path(work_package), params: create_params(entry_date: 7.days.ago.to_date)
      end.to change(DailyReport::WorkPackageEntry, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "rejects a participant entry older than seven days" do
      expect do
        post work_package_daily_report_entries_path(work_package), params: create_params(entry_date: 8.days.ago.to_date)
      end.not_to change(DailyReport::WorkPackageEntry, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("errors", "entry_date")).to be_present
    end

    it "requires problems and risks for a report entry" do
      params = create_params(entry_date: Date.current)
      params[:daily_report_entry][:issue_text] = ""
      params[:daily_report_entry][:risks_text] = ""

      post work_package_daily_report_entries_path(work_package), params: params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.fetch("errors").keys).to include("issue_text", "risks_text")
    end
  end

  describe "GET /work_packages/:work_package_id/daily_report_entries" do
    it "returns only the current participant's entries" do
      own_entry
      other_entry

      get work_package_daily_report_entries_path(work_package)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("own yesterday")
      expect(response.body).not_to include("other yesterday")
    end

    it "allows an Ausbilder global permission to read all visible entries" do
      own_entry
      other_entry
      ausbilder = create(
        :user,
        global_permissions: %i[manage_daily_report_entries],
        member_with_permissions: { project => %i[view_work_packages] }
      )
      login_as(ausbilder)

      get work_package_daily_report_entries_path(work_package)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("own yesterday", "other yesterday")
    end

    it "returns correction comments and changed fields only for corrected entries" do
      entry = own_entry
      entry.revisions.create!(
        revision_number: 1, event: "created", actor: participant,
        yesterday_text: "before", today_text: "same", issue_text: "problem", risks_text: "risk"
      )
      entry.revisions.create!(
        revision_number: 2, event: "corrected", comment: "Tippfehler behoben", actor: participant,
        yesterday_text: "after", today_text: "same", issue_text: "problem", risks_text: "risk"
      )

      get work_package_daily_report_entries_path(work_package)

      correction = response.parsed_body.first.fetch("correction_history").first
      expect(correction).to include("comment" => "Tippfehler behoben")
      expect(correction.fetch("actor")).to include("id" => participant.id, "name" => participant.name)
      expect(correction.fetch("changes")).to contain_exactly(
        "field" => "yesterday_text", "before" => "before", "after" => "after"
      )
    end

    it "authenticates an external read request with an API token and preserves participant scoping" do
      own_entry
      other_entry
      api_token = create(:api_token, user: participant)
      allow(RequestStore).to receive(:[]).and_call_original

      get work_package_daily_report_entries_path(work_package, format: :json),
          headers: { "X-OpenProject-API-Key" => api_token.plain_value }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("id")).to contain_exactly(own_entry.id)
      expect(response.parsed_body.first).to include(
        "author" => { "id" => participant.id, "name" => participant.name },
        "work_package" => { "id" => work_package.id, "subject" => work_package.subject },
        "project" => { "id" => project.id, "name" => project.name }
      )
    end

    it "rejects an invalid API token" do
      allow(RequestStore).to receive(:[]).and_call_original

      get work_package_daily_report_entries_path(work_package, format: :json),
          headers: { "X-OpenProject-API-Key" => "invalid" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /work_packages/:work_package_id/daily_report_entries/:id" do
    it "does not expose another participant's entry" do
      patch work_package_daily_report_entry_path(work_package, other_entry), params: update_params

      expect(response).to have_http_status(:not_found)
      expect(other_entry.reload.today_text).to eq("other today")
    end

    it "forbids participant edits of their own saved entry" do
      patch work_package_daily_report_entry_path(work_package, own_entry), params: update_params

      expect(response).to have_http_status(:forbidden)
      expect(own_entry.reload.today_text).to eq("own today")
    end
  end

  describe "DELETE /work_packages/:work_package_id/daily_report_entries/:id" do
    it "does not expose another participant's entry" do
      delete work_package_daily_report_entry_path(work_package, other_entry), params: { lock_version: 0 }

      expect(response).to have_http_status(:not_found)
      expect(other_entry.reload.deleted_at).to be_nil
    end

    it "forbids a participant from deleting their own saved entry" do
      delete work_package_daily_report_entry_path(work_package, own_entry), params: { lock_version: 0 }

      expect(response).to have_http_status(:forbidden)
      expect(own_entry.reload.deleted_at).to be_nil
    end

    it "allows an admin to soft-delete and preserves the audit record" do
      admin = create(:admin)
      login_as(admin)

      expect do
        delete work_package_daily_report_entry_path(work_package, own_entry), params: { lock_version: 0, comment: "duplicate" }
      end.to change(DailyReport::AuditEvent, :count).by(1)

      expect(response).to have_http_status(:no_content)
      expect(own_entry.reload.deleted_at).to be_present
      expect(own_entry.audit_events.last.event).to eq("deleted")
    end
  end

  def create_entry(author:, yesterday_text:, today_text:)
    DailyReport::WorkPackageEntry.create!(
      author:,
      work_package:,
      entry_date: Date.current,
      yesterday_text:,
      today_text:,
      issue_text: "own problem",
      risks_text: "own risk",
      updated_by: author
    )
  end

  def update_params
    {
      daily_report_entry: {
        lock_version: 0,
        comment: "correction",
        yesterday_text: "changed yesterday",
        today_text: "changed today",
        issue_text: "changed problem",
        risks_text: "changed risk"
      }
    }
  end

  def create_params(entry_date:)
    {
      daily_report_entry: {
        entry_date:,
        entry_kind: "report",
        yesterday_text: "yesterday",
        today_text: "today",
        issue_text: "problem",
        risks_text: "risk"
      }
    }
  end
end
