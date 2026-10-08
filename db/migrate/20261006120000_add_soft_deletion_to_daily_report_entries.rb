# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

class AddSoftDeletionToDailyReportEntries < ActiveRecord::Migration[8.1]
  def up
    add_column :daily_report_work_package_entries, :deleted_at, :datetime
    add_reference :daily_report_work_package_entries,
                  :deleted_by_user,
                  foreign_key: { to_table: :users }

    remove_index :daily_report_work_package_entries,
                 name: "index_daily_report_entries_unique_author_work_package_date"
    add_index :daily_report_work_package_entries,
              %i[author_user_id work_package_id entry_date],
              unique: true,
              where: "deleted_at IS NULL",
              name: "index_daily_report_active_entries_unique"
  end

  def down
    remove_index :daily_report_work_package_entries,
                 name: "index_daily_report_active_entries_unique"
    add_index :daily_report_work_package_entries,
              %i[author_user_id work_package_id entry_date],
              unique: true,
              name: "index_daily_report_entries_unique_author_work_package_date"

    remove_reference :daily_report_work_package_entries, :deleted_by_user
    remove_column :daily_report_work_package_entries, :deleted_at
  end
end
