# frozen_string_literal: true

require "spec_helper"

RSpec.describe Queries::Notifications::Filters::ActorCustomFieldFilter do
  shared_let(:project) { create(:project) }
  shared_let(:recipient) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }
  shared_let(:work_package) { create(:work_package, project:) }
  shared_let(:custom_field) { create(:user_custom_field, :string, name: "Lehrjahr") }
  shared_let(:department_custom_field) { create(:user_custom_field, :string, name: "Department") }
  shared_let(:matching_actor) do
    create(:user, custom_field_values: { custom_field.id => "LJ_1", department_custom_field.id => "IT" })
  end
  shared_let(:other_actor) do
    create(:user, custom_field_values: { custom_field.id => "LJ_2", department_custom_field.id => "HR" })
  end
  shared_let(:matching_notification) do
    create(:notification, recipient:, resource: work_package, actor: matching_actor)
  end
  shared_let(:other_notification) do
    create(:notification, recipient:, resource: work_package, actor: other_actor)
  end

  let(:query) { Queries::Notifications::NotificationQuery.new(user: recipient) }

  current_user { recipient }

  before do
    matching_notification
    other_notification

    query.where(:"actor_cf_#{custom_field.id}", "=", ["LJ_1"])
  end

  it "filters notifications by the actor user custom field" do
    expect(query).to be_valid
    expect(query.results).to contain_exactly(matching_notification)
  end

  it "filters notifications by multiple user attribute values" do
    query.where(described_class.filter_name(custom_field),
                "=",
                %w[LJ_1 LJ_2])

    expect(query).to be_valid
    expect(query.results).to contain_exactly(matching_notification, other_notification)
  end

  it "combines different user attributes" do
    query.where(described_class.filter_name(department_custom_field), "=", ["IT"])

    expect(query).to be_valid
    expect(query.results).to contain_exactly(matching_notification)
  end
end
