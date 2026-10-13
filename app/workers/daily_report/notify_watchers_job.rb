# frozen_string_literal: true

module DailyReport
  class NotifyWatchersJob < ApplicationJob
    queue_with_priority :notification

    def perform(entry_id, actor_id, event)
      entry = WorkPackageEntry.find(entry_id)
      actor = User.find(actor_id)

      NotifyWatchersService.new.call(entry:, actor:, event:)
    end
  end
end
