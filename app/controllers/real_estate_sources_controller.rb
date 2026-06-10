class RealEstateSourcesController < ApplicationController
  # GET /real_estate_sources — stored-sources read-back. Filter via ransack q[...]
  # (e.g. ?q[supplier_eq]=mogi&q[status_eq]=active), paginate via pagy (25/page).
  def index
    scope = RealEstateSource.ransack(params[:q]).result.order(last_seen_at: :desc)
    pagy, records = pagy(scope)
    collection = RealEstateSourceCollection.new(real_estate_sources: records, pagination: pagination_for(pagy))
    render_representer(RealEstateSourcesRepresenter.new(collection))
  end
end
