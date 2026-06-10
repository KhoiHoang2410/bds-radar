class RealEstateSourcesController < ApplicationController
  # GET /real_estate_sources — the minimal read-back of stored sources (tracer-bullet
  # proof that fetch→store→read works). Optional supplier / province_id / status filters.
  def index
    result = RealEstateSourceIndexContract.new.call(filter_params)
    return render_errors(result.errors.to_h) unless result.success?

    sources = RealEstateSource.where(result.to_h).order(last_seen_at: :desc)
    collection = RealEstateSourceCollection.new(real_estate_sources: sources.to_a)
    render_representer(RealEstateSourcesRepresenter.new(collection))
  end

  private

  def filter_params
    params.permit(:supplier, :province_id, :status).to_h.symbolize_keys
  end
end
