# frozen_string_literal: true

class AddStatusesAndCommentsToDailyReportEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :daily_report_work_package_entries, :entry_kind, :string, null: false, default: "report"
    add_column :daily_report_work_package_entries, :status_type, :string
    change_column_null :daily_report_work_package_entries, :yesterday_text, true
    change_column_null :daily_report_work_package_entries, :today_text, true

    add_column :daily_report_work_package_entry_revisions, :comment, :text
    change_column_null :daily_report_work_package_entry_revisions, :yesterday_text, true
    change_column_null :daily_report_work_package_entry_revisions, :today_text, true
    add_column :daily_report_audit_events, :comment, :text
  end
end
