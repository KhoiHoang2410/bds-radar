class ProvincesController < ApplicationController
  # GET /provinces — the crawl-control surface, ordered by name.
  def index
    collection = ProvinceCollection.new(provinces: Province.order(:name).to_a)
    render_representer(ProvincesRepresenter.new(collection))
  end

  # PATCH /provinces/:id — toggle schedule_fetch / adjust fetch_page_depth.
  def update
    province = Province.find(params[:id])
    result = ProvinceUpdateContract.new.call(update_params)
    return render_errors(result.errors.to_h) unless result.success?

    province.update!(result.to_h)
    render_representer(ProvinceRepresenter.new(province))
  end

  private

  def update_params
    source = params[:province].presence || params
    source.permit(:schedule_fetch, :fetch_page_depth).to_h.symbolize_keys
  end
end
