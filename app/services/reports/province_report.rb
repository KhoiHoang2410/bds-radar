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
        price_per_bedroom: { condo: price_per_bedroom_for("condo"), land: price_per_bedroom_for("land") },
        land_price_per_m2: land_price_per_m2,
        price_distribution: price_distribution,
        condo_by_project: condo_by_project
      }
    end

    private

    # Condos grouped by project_name (rows with a blank project excluded). Per project:
    # how many active condos, the average price of its 1- and 2-bedroom units, and the
    # average price per m². The HTML report exposes these behind a project dropdown.
    def condo_by_project
      rows = @scope.where(type: "condo").where.not(project_name: [ nil, "" ])
                   .group(:project_name)
                   .pluck(
                     :project_name,
                     Arel.sql("COUNT(*)"),
                     Arel.sql("AVG(price) FILTER (WHERE bedrooms = 1)"),
                     Arel.sql("AVG(price) FILTER (WHERE bedrooms = 2)"),
                     Arel.sql("AVG(price::numeric / area) FILTER (WHERE area > 0)")
                   )
      rows.map do |name, count, avg_1bed, avg_2bed, avg_per_m2|
        {
          project_name: name,
          count: count,
          avg_price_1bed: avg_1bed&.to_f,
          avg_price_2bed: avg_2bed&.to_f,
          avg_price_per_m2: avg_per_m2&.to_f
        }
      end.sort_by { |row| [ -row[:count], row[:project_name] ] }
    end

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

    # Land has no bedrooms, so price/m² is its comparable unit metric.
    def land_price_per_m2
      scope = @scope.where(type: "land").where("area > 0 AND price IS NOT NULL")
      count = scope.count
      return { count: 0, avg_price_per_m2: nil, avg_area: nil } if count.zero?

      {
        count: count,
        avg_price_per_m2: scope.pluck(Arel.sql("AVG(price::numeric / area)")).first&.to_f,
        avg_area: scope.pluck(Arel.sql("AVG(area)")).first&.to_f
      }
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
