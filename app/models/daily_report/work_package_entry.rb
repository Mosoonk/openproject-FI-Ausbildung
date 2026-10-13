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

module DailyReport
  class WorkPackageEntry < ApplicationRecord
    self.table_name = "daily_report_work_package_entries"

    ENTRY_KINDS = %w[report status].freeze
    STATUS_TYPES = %w[berufsschule praktikum krank betrieb].freeze

    belongs_to :author, class_name: "User", foreign_key: :author_user_id, inverse_of: false
    belongs_to :work_package
    belongs_to :updated_by, class_name: "User", foreign_key: :updated_by_user_id, inverse_of: false
    belongs_to :deleted_by, class_name: "User", foreign_key: :deleted_by_user_id, inverse_of: false, optional: true

    has_many :revisions,
             class_name: "DailyReport::WorkPackageEntryRevision",
             inverse_of: :work_package_entry,
             dependent: :restrict_with_exception
    has_many :audit_events,
             class_name: "DailyReport::AuditEvent",
             inverse_of: :work_package_entry,
             dependent: :nullify

    validates :author, :work_package, :updated_by, :entry_date, :entry_kind, presence: true
    validates :entry_kind, inclusion: { in: ENTRY_KINDS }
    validates :status_type, inclusion: { in: STATUS_TYPES }, if: :status?
    validates :status_type, inclusion: { in: ["betrieb"] }, allow_nil: true, if: :report?
    validates :yesterday_text, :today_text, :issue_text, :risks_text, presence: true, if: :report?
    scope :active, -> { where(deleted_at: nil) }

    validates :author_user_id,
              uniqueness: {
                scope: %i[work_package_id entry_date],
                conditions: -> { where(deleted_at: nil) }
              }
    validate :entry_date_is_not_in_the_future
    validate :status_entry_has_no_report_text

    def report?
      entry_kind == "report"
    end

    def status?
      entry_kind == "status"
    end

    private

    def entry_date_is_not_in_the_future
      return if entry_date.blank? || entry_date <= Date.current

      errors.add(:entry_date, :in_future)
    end

    def status_entry_has_no_report_text # rubocop:disable Metrics/AbcSize
      return unless status?

      errors.add(:yesterday_text, :present) if yesterday_text.present?
      errors.add(:today_text, :present) if today_text.present?
      errors.add(:issue_text, :present) if issue_text.present?
      errors.add(:risks_text, :present) if risks_text.present?
    end
  end
end
