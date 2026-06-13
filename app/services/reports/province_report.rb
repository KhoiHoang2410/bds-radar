module Reports
  # Aggregates a province's active RealEstate rows into the figures the PDF renders.
  # Pure computation (no I/O beyond the scoped queries) so it's cheap to unit-test;
  # the renderer (ProvinceReportPdf) only formats what this returns.
  #
  # Money is VND. Bedroom-based metrics only consider rows with a positive bedroom
  # count (land usually has none, so its per-bedroom table is typically empty —
  # land is better judged by price/m², which we also report).
  class ProvinceReport
    # [label, lower_bound_inclusive, upper_bound_exclusive] in VND; nil upper = open-ended.
    PRICE_BUCKETS = [
      [ "< 1 tỷ",     0,               1_000_000_000 ],
      [ "1 – 3 tỷ",   1_000_000_000,   3_000_000_000 ],
      [ "3 – 5 tỷ",   3_000_000_000,   5_000_000_000 ],
      [ "5 – 10 tỷ",  5_000_000_000,   10_000_000_000 ],
      [ "10 – 20 tỷ", 10_000_000_000,  20_000_000_000 ],
      [ "≥ 20 tỷ",    20_000_000_000,  nil ]
    ].freeze

    # [label, lower_bound_inclusive, upper_bound_exclusive] in m²; nil upper = open-ended.
    # Land has no bedrooms, so it's analysed by lot size instead.
    AREA_BUCKETS = [
      [ "< 30 m²",      0,    30 ],
      [ "30 – 50 m²",   30,   50 ],
      [ "50 – 70 m²",   50,   70 ],
      [ "70 – 100 m²",  70,   100 ],
      [ "100 – 150 m²", 100,  150 ],
      [ "≥ 150 m²",     150,  nil ]
    ].freeze

    def self.call(province)
      new(province).call
    end

    def initialize(province)
      @province = province
      @scope = RealEstate.active.where(province_id: province.id)
    end

    def call
      {
        province: @province,
        total_count: @scope.count,
        by_type: by_type,
        by_bedrooms: by_bedrooms,
        price_per_bedroom: { condo: price_per_bedroom_for("condo") },
        land_by_ward_area: land_by_ward_area,
        price_distribution: price_distribution
      }
    end

    private

    # Per bedroom count (across all types): how many, and average price. Rows with no
    # bedroom count (e.g. land) are excluded — they're covered by price/m² instead.
    def by_bedrooms
      rows = @scope.where.not(bedrooms: nil).group(:bedrooms)
                   .pluck(:bedrooms, Arel.sql("COUNT(*)"), Arel.sql("AVG(price)"))
      rows.map do |bedrooms, count, avg_price|
        { bedrooms: bedrooms, count: count, avg_price: avg_price&.to_f }
      end.sort_by { |row| row[:bedrooms] }
    end

    # Per property type: how many, average price, average area.
    def by_type
      rows = @scope.group(:type).pluck(:type, Arel.sql("COUNT(*)"), Arel.sql("AVG(price)"), Arel.sql("AVG(area)"))
      rows.map do |type, count, avg_price, avg_area|
        { type: type || "unknown", count: count, avg_price: avg_price&.to_f, avg_area: avg_area&.to_f }
      end.sort_by { |row| -row[:count] }
    end

    # For one type, break down by bedroom count: count, average price, and the
    # headline figure — average price per bedroom (price ÷ bedrooms, averaged).
    def price_per_bedroom_for(type)
      rows = @scope.where(type: type).where("bedrooms > 0 AND price IS NOT NULL")
                   .group(:bedrooms)
                   .pluck(:bedrooms, Arel.sql("COUNT(*)"), Arel.sql("AVG(price)"), Arel.sql("AVG(price::numeric / bedrooms)"))
      rows.map do |bedrooms, count, avg_price, avg_per_bedroom|
        { bedrooms: bedrooms, count: count, avg_price: avg_price&.to_f, avg_price_per_bedroom: avg_per_bedroom&.to_f }
      end.sort_by { |row| row[:bedrooms] }
    end

    # SQL CASE that maps a row's area to its AREA_BUCKETS index (0-based, last = open-ended).
    AREA_BUCKET_CASE = Arel.sql(<<~SQL.squish).freeze
      CASE
        WHEN area < 30 THEN 0
        WHEN area < 50 THEN 1
        WHEN area < 70 THEN 2
        WHEN area < 100 THEN 3
        WHEN area < 150 THEN 4
        ELSE 5
      END
    SQL

    # Land broken down by ward, then by lot size (land has no bedrooms). One row per
    # ward that has land listings, each carrying the full AREA_BUCKETS breakdown
    # (count, average price, average price/m²). Wards are ordered by listing count desc.
    # Computed in a single grouped query (ward × bucket) to avoid N+1 over wards.
    def land_by_ward_area
      rows = @scope.where(type: "land").where("area > 0 AND price IS NOT NULL")
                   .group(:ward, AREA_BUCKET_CASE)
                   .pluck(:ward, AREA_BUCKET_CASE, Arel.sql("COUNT(*)"),
                          Arel.sql("AVG(price)"), Arel.sql("AVG(price::numeric / area)"))

      by_ward = Hash.new { |h, k| h[k] = {} }
      rows.each do |ward, bucket_index, count, avg_price, avg_per_m2|
        by_ward[ward][bucket_index] =
          { count: count, avg_price: avg_price&.to_f, avg_price_per_m2: avg_per_m2&.to_f }
      end

      by_ward.map do |ward, cells|
        buckets = AREA_BUCKETS.each_index.map do |i|
          cell = cells[i]
          {
            label: AREA_BUCKETS[i][0],
            count: cell ? cell[:count] : 0,
            avg_price: cell && cell[:avg_price],
            avg_price_per_m2: cell && cell[:avg_price_per_m2]
          }
        end
        { ward: ward, count: buckets.sum { |b| b[:count] }, buckets: buckets }
      end.sort_by { |row| [ -row[:count], row[:ward].to_s ] }
    end

    # Count of listings whose price falls in each bucket (rows with NULL price excluded).
    def price_distribution
      priced = @scope.where.not(price: nil)
      PRICE_BUCKETS.map do |label, low, high|
        scope = priced.where("price >= ?", low)
        scope = scope.where("price < ?", high) if high
        { label: label, count: scope.count }
      end
    end
  end
end
