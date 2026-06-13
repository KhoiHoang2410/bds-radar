# Geo-grid aggregation for the price heatmap (ADR-0003): cells are derived
# ONLY from stored latitude/longitude — no ward polygons, no geocoding, no
# external boundary data. We snap each listing into a bin by rounding its
# lat/lng to `precision` decimals (default 2 ≈ ~1.1km bins); the rounded value
# is the cell's anchor coordinate.
class MapGridAggregator
  DEFAULT_PRECISION = 2
  MIN_PRECISION = 0
  MAX_PRECISION = 6

  MapCell = Struct.new(:lat, :lng, :count, :median_price, :price_per_m2, keyword_init: true)

  def self.clamp_precision(value)
    (value.presence || DEFAULT_PRECISION).to_i.clamp(MIN_PRECISION, MAX_PRECISION)
  end

  def self.call(scope, precision: DEFAULT_PRECISION)
    new(scope, precision: precision).call
  end

  def initialize(scope, precision: DEFAULT_PRECISION)
    @scope = scope
    @precision = self.class.clamp_precision(precision)
  end

  def call
    rows = @scope.where.not(latitude: nil, longitude: nil).pluck(:latitude, :longitude, :price, :area)
    rows.group_by { |lat, lng, _price, _area| [ lat.round(@precision), lng.round(@precision) ] }
        .map { |(cell_lat, cell_lng), cell_rows| build_cell(cell_lat, cell_lng, cell_rows) }
  end

  private

  def build_cell(lat, lng, rows)
    prices = rows.filter_map { |_la, _ln, price, _area| price }
    # price_per_m2 = median of each listing's own price/area ratio (skipping rows
    # with no/zero area). Per-listing ratios are more robust to mixed-area cells
    # than median(price) / median(area), and answer "what does a m2 cost here?".
    ratios = rows.filter_map { |_la, _ln, price, area| price.to_f / area.to_f if price && area && area.positive? }

    MapCell.new(
      lat: lat.to_f,
      lng: lng.to_f,
      count: rows.size,
      median_price: median(prices)&.round,
      price_per_m2: median(ratios)&.round(2)
    )
  end

  def median(values)
    return nil if values.empty?

    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end
end
