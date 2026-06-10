class ApplicationController < ActionController::API
  include Pagy::Backend

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  before_action :require_json_content_type, if: :request_has_body?

  private

  # JSON in / JSON only out: reject a write whose body is not application/json.
  def require_json_content_type
    return if request.content_type.to_s.start_with?("application/json")

    render_errors({ content_type: [ "must be application/json" ] }, status: :unsupported_media_type)
  end

  def request_has_body?
    request.post? || request.patch? || request.put?
  end

  def render_representer(representer, status: :ok)
    render body: representer.to_json, content_type: "application/json", status: status
  end

  def render_errors(errors, status: :unprocessable_entity)
    render_representer(ErrorRepresenter.new(ApiErrors.new(errors: errors)), status: status)
  end

  def render_not_found
    render_errors({ base: [ "not found" ] }, status: :not_found)
  end

  # Map a Pagy object to our serializable pagination value object.
  def pagination_for(pagy)
    Pagination.new(page: pagy.page, per_page: pagy.limit, total_count: pagy.count, total_pages: pagy.pages)
  end
end
