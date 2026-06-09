# Builds the filtered RealEstate relation for the query API. Canonical keys where
# they exist (province_id, ward_city_id), raw string only where none does
# (district_or_city). Defaults to active rows.
class RealEstateQuery
  def self.call(filters)
    new(filters).relation
  end

  def initialize(filters)
    @f = filters.symbolize_keys
  end

  def relation
    scope = RealEstate.where(status: @f.fetch(:status, "active"))
    scope = scope.where(province_id: @f[:province_id]) if @f[:province_id]
    scope = scope.where(ward_city_id: @f[:ward_city_id]) if @f[:ward_city_id]
    scope = scope.where(district_or_city: @f[:district_or_city]) if @f[:district_or_city].present?
    scope = scope.where(type: @f[:type]) if @f[:type].present?
    scope = scope.where(price: @f[:min_price]..) if @f[:min_price]
    scope = scope.where(price: ..@f[:max_price]) if @f[:max_price]
    scope = scope.where(area: @f[:min_area]..) if @f[:min_area]
    scope = scope.where(area: ..@f[:max_area]) if @f[:max_area]
    scope = apply_bbox(scope)
    scope.order(created_at: :desc)
  end

  private

  # bbox = "sw_lat,sw_lng,ne_lat,ne_lng" — a coordinate window (canonical coords).
  def apply_bbox(scope)
    return scope if @f[:bbox].blank?

    sw_lat, sw_lng, ne_lat, ne_lng = @f[:bbox].split(",").map { |p| Float(p) }
    scope.where(latitude: sw_lat..ne_lat, longitude: sw_lng..ne_lng)
  end
end
