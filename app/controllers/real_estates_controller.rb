class RealEstatesController < ApplicationController
  # GET /real_estates — the consumable analytics API. Filters: province (canonical
  # province_id), ward (ward_city_id), district (raw), type, price/area range, bbox,
  # status (default active).
  def index
    result = RealEstateIndexContract.new.call(filter_params)
    return render_errors(result.errors.to_h) unless result.success?

    real_estates = RealEstateQuery.call(result.to_h).to_a
    render_representer(RealEstatesRepresenter.new(RealEstateCollection.new(real_estates: real_estates)))
  end

  # GET /real_estates/:id
  def show
    render_representer(RealEstateRepresenter.new(RealEstate.find(params[:id])))
  end

  private

  def filter_params
    params.permit(
      :province_id, :ward_city_id, :district_or_city, :type, :status,
      :min_price, :max_price, :min_area, :max_area, :bbox
    ).to_h.symbolize_keys
  end
end
