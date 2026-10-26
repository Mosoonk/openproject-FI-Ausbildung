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

class Queries::Notifications::Filters::ActorCustomFieldFilter < Queries::Notifications::Filters::NotificationFilter
  class << self
    def key
      /\Aactor_cf_(\d+)\z/
    end

    def all_for(context = nil)
      UserCustomField.visible(User.current).filter_map do |custom_field|
        create!(name: filter_name(custom_field), custom_field:, context:)
      end
    end

    def create!(name:, **)
      custom_field = UserCustomField.visible(User.current).find_by(id: custom_field_id(name))
      raise Queries::Filters::InvalidError if custom_field.nil?

      new(name, custom_field:, **)
    end

    def filter_name(custom_field)
      "actor_cf_#{custom_field.id}"
    end

    private

    def custom_field_id(name)
      name.to_s.match(key)&.captures&.first
    end
  end

  attr_reader :custom_field

  def initialize(name, custom_field:, **options)
    @custom_field = custom_field

    super(name, options)
  end

  def human_name
    custom_field.name
  end

  def type
    :string
  end

  def where
    <<~SQL.squish
      #{Notification.table_name}.actor_id IN (
        SELECT #{User.table_name}.id
        FROM #{User.table_name}
        INNER JOIN #{CustomValue.table_name}
          ON #{CustomValue.table_name}.customized_type = 'Principal'
          AND #{CustomValue.table_name}.customized_id = #{User.table_name}.id
          AND #{CustomValue.table_name}.custom_field_id = #{custom_field.id}
        WHERE #{operator_strategy.sql_for_field(values, CustomValue.table_name, :value)}
      )
    SQL
  end
end
