# frozen_string_literal: true

require "spec_helper"

RSpec.describe Notifications::MenusController do
  render_views

  shared_let(:project) { create(:project) }
  shared_let(:user) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }
  shared_let(:work_package) { create(:work_package, project:) }
  shared_let(:custom_field) { create(:user_custom_field, :string, name: "Lehrjahr") }
  shared_let(:actor) { create(:user, custom_field_values: { custom_field.id => "LJ_1" }) }
  shared_let(:notification) { create(:notification, recipient: user, resource: work_package, actor:) }

  current_user { user }

  before do
    login_as(user)
    notification
  end

  it "renders custom user attribute values as checkboxes with an apply button" do
    get :show

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "name=\"filters[actor_cf_#{custom_field.id}][]\"",
      'value="LJ_1"',
      "Apply"
    )
    expect(response.body).not_to include('type="hidden" value="0"')
    rendered = Capybara.string(response.body)

    expect(rendered).to have_css(
      "li.op-submenu--item[data-filter--filter-list-target='searchItem'] " \
      "label.op-submenu--item-action[data-test-selector='op-submenu--item-action']"
    )
    expect(rendered).to have_css(
      "label.op-submenu--item-action input.FormControl-checkbox + span.op-submenu--item-title",
      text: "LJ_1"
    )
  end
end
