# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class CreateDailyReportEntries < ActiveRecord::Migration[8.1]
  def change
    create_entries
    create_revisions
    create_audit_events
  end

  private

  def create_entries
    create_table :daily_report_work_package_entries do |t|
      t.references :author_user, null: false, foreign_key: { to_table: :users }
      t.references :work_package, null: false, foreign_key: true
      t.date :entry_date, null: false
      t.text :yesterday_text, null: false
      t.text :today_text, null: false
      t.text :issue_text
      t.text :risks_text
      t.references :updated_by_user, null: false, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.index %i[author_user_id work_package_id entry_date],
              unique: true,
              name: "index_daily_report_entries_unique_author_work_package_date"
    end
  end

  def create_revisions
    create_table :daily_report_work_package_entry_revisions do |t|
      t.references :work_package_entry,
                   null: false,
                   foreign_key: { to_table: :daily_report_work_package_entries }
      t.integer :revision_number, null: false
      t.string :event, null: false
      t.references :actor_user, null: false, foreign_key: { to_table: :users }
      t.text :yesterday_text, null: false
      t.text :today_text, null: false
      t.text :issue_text
      t.text :risks_text
      t.datetime :created_at, null: false

      t.index %i[work_package_entry_id revision_number],
              unique: true,
              name: "index_daily_report_entry_revisions_unique_sequence"
    end
  end

  def create_audit_events
    create_table :daily_report_audit_events do |t|
      t.references :work_package_entry,
                   foreign_key: { to_table: :daily_report_work_package_entries, on_delete: :nullify }
      t.references :work_package, null: false, foreign_key: true
      t.references :author_user, null: false, foreign_key: { to_table: :users }
      t.references :actor_user, null: false, foreign_key: { to_table: :users }
      t.string :event, null: false
      t.datetime :created_at, null: false
    end
  end
end
