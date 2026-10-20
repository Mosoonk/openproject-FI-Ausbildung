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

class CreateDailyReportUserUnavailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_report_user_unavailabilities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :weekdays, array: true, null: false, default: []
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.references :updated_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :deleted_at
      t.references :deleted_by_user, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.index %i[user_id start_date end_date], name: "index_daily_report_unavailabilities_on_user_and_dates"
    end

    add_check_constraint :daily_report_user_unavailabilities,
                         "kind IN ('berufsschule', 'urlaub', 'krank')",
                         name: "daily_report_unavailability_kind"
    add_check_constraint :daily_report_user_unavailabilities,
                         "start_date <= end_date",
                         name: "daily_report_unavailability_dates"
    add_check_constraint :daily_report_user_unavailabilities,
                         "weekdays <@ ARRAY[1, 2, 3, 4, 5, 6, 7]",
                         name: "daily_report_unavailability_weekdays"

    create_table :daily_report_user_unavailability_revisions do |t|
      t.references :user_unavailability,
                   null: false,
                   foreign_key: { to_table: :daily_report_user_unavailabilities }
      t.integer :revision_number, null: false
      t.string :event, null: false
      t.references :actor_user, null: false, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :weekdays, array: true, null: false, default: []
      t.datetime :created_at, null: false

      t.index %i[user_unavailability_id revision_number],
              unique: true,
              name: "index_daily_report_unavailability_revisions_unique_sequence"
    end

    create_table :daily_report_work_package_schedule_settings do |t|
      t.references :work_package, null: false, foreign_key: true, index: { unique: true }
      t.string :excluded_unavailability_kinds, array: true, null: false, default: []
      t.timestamps
    end

    add_check_constraint :daily_report_work_package_schedule_settings,
                         "excluded_unavailability_kinds <@ ARRAY['berufsschule', 'urlaub', 'krank']::varchar[]",
                         name: "daily_report_schedule_setting_excluded_kinds"
  end
end
