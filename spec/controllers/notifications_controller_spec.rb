# frozen_string_literal: true

require "spec_helper"

RSpec.describe NotificationsController do
  shared_let(:user) { create(:user) }
  shared_let(:custom_field) { create(:user_custom_field, :string, name: "Lehrjahr") }

  current_user { user }

  before do
    login_as(user)
    custom_field
  end

  it "accepts user attribute filters submitted by the shared form" do
    get :index, params: { filters: { "actor_cf_#{custom_field.id}" => ["LJ_1"] } }

    expect(response).to be_successful
  end
end
