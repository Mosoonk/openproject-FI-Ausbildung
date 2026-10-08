# frozen_string_literal: true

require "spec_helper"

RSpec.describe DailyReport::NotifyWatchersService, type: :model do
  let(:project) { create(:project) }
  let(:actor) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }
  let(:watcher_user) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }
  let(:work_package) { create(:work_package, project:, assigned_to: actor) }
  let(:entry) do
    DailyReport::WorkPackageEntry.create!(
      author: actor,
      work_package:,
      updated_by: actor,
      entry_date: Date.current,
      yesterday_text: "yesterday",
      today_text: "today",
      issue_text: "problem",
      risks_text: "risk"
    )
  end

  before do
    create(:watcher, watchable: work_package, user: watcher_user)
    create(:notification_setting, user: watcher_user, project:, watched: true)
  end

  it "creates one in-app notification for an eligible watcher and is idempotent" do
    service = described_class.new

    expect do
      service.call(entry:, actor:, event: "created")
      service.call(entry:, actor:, event: "created")
    end.to change(Notification, :count).by(1)
      .and change(DailyReport::NotificationDelivery, :count).by(1)

    notification = Notification.last
    expect(notification).to have_attributes(recipient: watcher_user, actor:, resource: work_package, reason: "daily_report")
    expect(notification.journal_id).to be_nil
  end

  it "excludes the actor even when the actor watches the Work Package" do
    create(:watcher, watchable: work_package, user: actor)
    create(:notification_setting, user: actor, project:, watched: true)

    described_class.new.call(entry:, actor:, event: "created")

    expect(Notification.where(recipient: actor)).to be_empty
  end

  it "does not notify a watcher whose watched preference is disabled" do
    NotificationSetting.where(user: watcher_user, project:).update_all(watched: false)

    expect do
      described_class.new.call(entry:, actor:, event: "created")
    end.not_to change(Notification, :count)
  end
end
