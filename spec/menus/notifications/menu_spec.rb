# frozen_string_literal: true

require "spec_helper"

RSpec.describe Notifications::Menu do
  shared_let(:project) { create(:project) }
  shared_let(:recipient) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }
  shared_let(:work_package) { create(:work_package, project:) }
  shared_let(:custom_field) { create(:user_custom_field, :string, name: "Lehrjahr") }
  shared_let(:actor) { create(:user, custom_field_values: { custom_field.id => "LJ_1" }) }
  shared_let(:second_actor) { create(:user, custom_field_values: { custom_field.id => "LJ_2" }) }
  shared_let(:notification) do
    create(:notification, recipient:, resource: work_package, actor:)
  end
  shared_let(:second_notification) do
    create(:notification, recipient:, resource: work_package, actor: second_actor)
  end

  current_user { recipient }

  before do
    notification
  end

  it "adds a filter for each visible user attribute value of notification actors" do
    menu = described_class.new(params: {}, current_user: recipient)
    item = menu.menu_items.flat_map(&:children).find { |menu_item| menu_item.title == "LJ_1" }

    expect(item.count).to eq(1)
    expect(item.href).to include("filter=actor_cf_#{custom_field.id}", "name=LJ_1")
  end

  it "exposes every user attribute value for selection in the form" do
    second_notification
    menu = described_class.new(params: { filter: "actor_cf_#{custom_field.id}", name: "LJ_1" }, current_user: recipient)
    item = menu.menu_items.flat_map(&:children).find { |menu_item| menu_item.title == "LJ_2" }

    expect(item.href).to include("filter=actor_cf_#{custom_field.id}", "name=LJ_2")
    expect(item.selected).to be(false)
  end

  it "marks values that are part of the active filter" do
    menu = described_class.new(params: { filter: "actor_cf_#{custom_field.id}", name: "LJ_1" }, current_user: recipient)
    item = menu.menu_items.flat_map(&:children).find { |menu_item| menu_item.title == "LJ_1" }

    expect(item.href).to include("name=LJ_1")
    expect(item.selected).to be(true)
  end
end
