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

module DailyReport
  class UserUnavailability < ApplicationRecord
    self.table_name = "daily_report_user_unavailabilities"

    KINDS = %w[berufsschule urlaub krank].freeze

    belongs_to :user
    belongs_to :created_by, class_name: "User", foreign_key: :created_by_user_id, inverse_of: false
    belongs_to :updated_by, class_name: "User", foreign_key: :updated_by_user_id, inverse_of: false
    belongs_to :deleted_by, class_name: "User", foreign_key: :deleted_by_user_id, inverse_of: false, optional: true

    has_many :revisions,
             class_name: "DailyReport::UserUnavailabilityRevision",
             inverse_of: :user_unavailability,
             dependent: :restrict_with_exception

    scope :active, -> { where(deleted_at: nil) }
    scope :for_user, ->(user) { where(user:) }
    scope :of_kinds, ->(kinds) { where(kind: kinds) }

    before_validation :normalize_weekdays

    validates :user, :created_by, :updated_by, :kind, :start_date, :end_date, presence: true
    validates :kind, inclusion: { in: KINDS }
    validate :end_date_not_before_start_date
    validate :weekdays_match_kind

    def unavailable_on?(date)
      return false unless date.between?(start_date, end_date)

      weekdays.empty? || weekdays.include?(date.cwday)
    end

    private

    def normalize_weekdays
      self.weekdays = Array(weekdays).filter_map do |weekday|
        next if weekday.blank?

        weekday.is_a?(String) ? Integer(weekday, exception: false) || weekday : weekday
      end
    end

    def end_date_not_before_start_date
      return unless start_date.present? && end_date.present? && end_date < start_date

      errors.add(:end_date, :not_before_start_date)
    end

    def weekdays_match_kind
      errors.add(:weekdays, :invalid) unless valid_weekdays?

      if kind == "berufsschule" && weekdays.empty?
        errors.add(:weekdays, :blank)
      elsif kind.present? && kind != "berufsschule" && weekdays.present?
        errors.add(:weekdays, :present)
      end
    end

    def valid_weekdays?
      weekdays.all? { |weekday| weekday.in?(1..7) } && weekdays.uniq == weekdays
    end
  end
end
