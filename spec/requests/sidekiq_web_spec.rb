require "rails_helper"

RSpec.describe "Sidekiq dashboard", type: :request do
  it "is mounted and renders (session middleware present)" do
    get "/sidekiq"
    expect(response).to have_http_status(:ok)
  end
end
