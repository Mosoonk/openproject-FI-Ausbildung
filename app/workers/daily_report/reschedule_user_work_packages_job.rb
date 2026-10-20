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
  class RescheduleUserWorkPackagesJob < ApplicationJob
    queue_with_priority :above_normal

    def perform(user_id, actor_id)
      participant = User.find(user_id)
      actor = User.find(actor_id)

      User.execute_as(actor) do
        WorkPackage
          .where(assigned_to_id: participant.id, ignore_non_working_days: false, schedule_manually: false)
          .find_each do |work_package|
            WorkPackages::UpdateService
              .new(user: actor, model: work_package, contract_class: EmptyContract)
              .call(duration: work_package.duration)
          end
      end
    end
  end
end
