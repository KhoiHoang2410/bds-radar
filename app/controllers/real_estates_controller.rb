class RealEstatesController < ApplicationController
  # GET /real_estates — the analytics API. Filter via ransack q[...] predicates:
  #   q[province_id_eq], q[ward_id_eq], q[district_or_city_cont], q[type_eq],
  #   q[price_gteq]/q[price_lteq], q[area_gteq]/q[area_lteq],
  #   q[project_name_cont], q[project_external_id_eq],
  #   bbox = q[latitude_gteq]/q[latitude_lteq] + q[longitude_gteq]/q[longitude_lteq].
  # Defaults to active rows unless q[status_eq] is given. Paginated via pagy (25/page).
  def index
    scope = base_scope.ransack(params[:q]).result.order(created_at: :desc)
    pagy, records = pagy(scope)
    collection = RealEstateCollection.new(real_estates: records, pagination: pagination_for(pagy))
    render_representer(RealEstatesRepresenter.new(collection))
  end

  # GET /real_estates/:id
  def show
    render_representer(RealEstateRepresenter.new(RealEstate.find(params[:id])))
  end

  # GET /real_estates/map — geo-grid-aggregated cells for the price heatmap.
  # Reuses index's base_scope + ransack filters (incl. the bbox via
  # q[latitude_gteq]/_lteq + q[longitude_gteq]/_lteq), then snaps coords into
  # bins (ADR-0003). Optional q-independent ?precision= overrides bin size.
  def map
    scope = base_scope.ransack(params[:q]).result
    precision = MapGridAggregator.clamp_precision(params[:precision])
    cells = MapGridAggregator.call(scope, precision: precision)
    render_representer(MapCellsRepresenter.new(MapCellCollection.new(cells: cells, precision: precision)))
  end

  private

  # Default to active rows unless the caller explicitly filters on status.
  def base_scope
    params.dig(:q, :status_eq).present? ? RealEstate.all : RealEstate.active
  end
end
