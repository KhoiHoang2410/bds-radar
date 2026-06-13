require "cgi"
require "json"

module Reports
  # Renders a ProvinceReport data hash into a self-contained HTML page (a single
  # string): summary stat cards, breakdown tables, and Chart.js charts for listings
  # by type, by bedroom count, average price by type, and the price-bucket
  # distribution. Chart.js is loaded from a CDN; the figures are embedded as JSON and
  # drawn client-side. Mirrors ProvinceReportPdf (pure formatting, no I/O).
  class ProvinceReportHtml
    BILLION = 1_000_000_000.0
    MILLION = 1_000_000.0
    CHART_CDN = "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js".freeze

    # `provinces` is the list shown in the report's province switcher — typically the
    # scheduled provinces. Empty (the default) renders no switcher.
    def self.call(report, provinces: [])
      new(report, provinces: provinces).render
    end

    def initialize(report, provinces: [])
      @report = report
      @provinces = provinces
    end

    def render
      <<~HTML
        <!DOCTYPE html>
        <html lang="vi">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Report for #{h(province_name)}</title>
        <script src="#{CHART_CDN}"></script>
        <style>#{styles}</style>
        </head>
        <body>
        <div class="wrap">
          #{header}
          #{stat_cards}
          #{charts_grid}
          #{condo_by_project_section}
          #{by_type_table}
          #{price_per_bedroom_tables}
          #{land_section}
        </div>
        <script>#{chart_script}</script>
        </body>
        </html>
      HTML
    end

    private

    def province_name
      @report[:province].name
    end

    def header
      <<~HTML
        <header>
          <h1>Báo cáo bất động sản</h1>
          <p class="province">#{h(province_name)}</p>
          #{province_selector}
        </header>
      HTML
    end

    # A dropdown to switch the report to another province; selecting one navigates to
    # that province's report. Populated with the provinces passed in (the scheduled
    # ones). Rendered only when a list is supplied. The current province is preselected.
    def province_selector
      return "" if @provinces.empty?

      current_id = @report[:province].id
      options = @provinces.map do |province|
        selected = province.id == current_id ? " selected" : ""
        %(<option value="#{province.id}"#{selected}>#{h(province.name)}</option>)
      end.join

      <<~HTML
        <div class="province-switch">
          <label for="provinceSelect">Đổi tỉnh / thành phố</label>
          <select id="provinceSelect" onchange="location.href='/provinces/' + this.value + '/report.html'">#{options}</select>
        </div>
      HTML
    end

    # Headline numbers: total listings, distinct types, the most common type, and the
    # overall average price (across priced rows).
    def stat_cards
      types = @report[:by_type]
      top = types.max_by { |r| r[:count] }
      avg_price = weighted_avg_price(types)

      cards = [
        [ "Tổng số tin", @report[:total_count].to_s ],
        [ "Số loại hình", types.size.to_s ],
        [ "Loại nhiều nhất", top ? "#{h(top[:type])} (#{top[:count]})" : "—" ],
        [ "Giá trung bình", money(avg_price) ]
      ]

      body = cards.map do |label, value|
        %(<div class="card"><div class="card-value">#{value}</div><div class="card-label">#{label}</div></div>)
      end.join

      %(<section class="cards">#{body}</section>)
    end

    def charts_grid
      <<~HTML
        <section class="charts">
          <div class="chart-box"><h2>Số tin theo loại hình</h2><canvas id="byType"></canvas></div>
          <div class="chart-box"><h2>Số tin theo số phòng ngủ</h2><canvas id="byBedrooms"></canvas></div>
          <div class="chart-box"><h2>Giá trung bình theo loại hình (tỷ)</h2><canvas id="avgPrice"></canvas></div>
          <div class="chart-box"><h2>Phân bố theo khoảng giá</h2><canvas id="priceDist"></canvas></div>
        </section>
      HTML
    end

    # Condo analysis grouped by project — one row per project (escaped), sorted by
    # count desc: number of available condos, 1- & 2-bedroom average price, price/m².
    def condo_by_project_section
      header_row = [ "Dự án", "Số căn", "Giá TB 1PN", "Giá TB 2PN", "Giá / m²" ]
      rows = @report[:condo_by_project].map do |row|
        [ h(row[:project_name]), row[:count].to_s,
          money(row[:avg_price_1bed]), money(row[:avg_price_2bed]),
          price_per_m2(row[:avg_price_per_m2]) ]
      end
      table("Căn hộ theo dự án", header_row, rows, empty: "Không có dữ liệu căn hộ theo dự án.")
    end

    def by_type_table
      header_row = %w[Loại Số\ lượng Giá\ TB Diện\ tích\ TB]
      rows = @report[:by_type].map do |row|
        [ h(row[:type]), row[:count].to_s, money(row[:avg_price]), area(row[:avg_area]) ]
      end
      table("Tổng quan theo loại hình", header_row, rows, empty: "Không có dữ liệu.")
    end

    def price_per_bedroom_tables
      { condo: "Căn hộ — giá theo số phòng ngủ", land: "Đất — giá theo số phòng ngủ" }.map do |key, title|
        rows = @report[:price_per_bedroom][key].map do |row|
          [ row[:bedrooms].to_s, row[:count].to_s, money(row[:avg_price]), money(row[:avg_price_per_bedroom]) ]
        end
        table(title, [ "Phòng ngủ", "Số lượng", "Giá TB", "Giá / phòng ngủ" ], rows,
              empty: "Không có dữ liệu phòng ngủ.")
      end.join
    end

    def land_section
      land = @report[:land_price_per_m2]
      rows =
        if land[:count].zero?
          []
        else
          [
            [ "Số tin", land[:count].to_s ],
            [ "Diện tích TB", area(land[:avg_area]) ],
            [ "Giá / m² (TB)", price_per_m2(land[:avg_price_per_m2]) ]
          ]
        end
      table("Đất — giá trên mỗi m²", nil, rows, empty: "Không có tin đất.")
    end

    # Builds a titled table; renders the empty-state note when there are no rows.
    def table(title, header_row, rows, empty:)
      inner =
        if rows.empty?
          %(<p class="empty">#{empty}</p>)
        else
          head = header_row ? "<thead><tr>#{header_row.map { |c| "<th>#{c}</th>" }.join}</tr></thead>" : ""
          body = rows.map { |cells| "<tr>#{cells.map { |c| "<td>#{c}</td>" }.join}</tr>" }.join
          %(<table>#{head}<tbody>#{body}</tbody></table>)
        end
      %(<section class="block"><h2>#{title}</h2>#{inner}</section>)
    end

    # The data the inline script turns into charts. Numbers only — labels are escaped
    # by Chart.js at render, and the JSON is embedded in a <script> (no HTML context).
    def chart_data
      {
        byType: {
          labels: @report[:by_type].map { |r| r[:type] },
          counts: @report[:by_type].map { |r| r[:count] },
          avgPriceTy: @report[:by_type].map { |r| r[:avg_price] ? (r[:avg_price] / BILLION).round(2) : 0 }
        },
        byBedrooms: {
          labels: @report[:by_bedrooms].map { |r| "#{r[:bedrooms]} PN" },
          counts: @report[:by_bedrooms].map { |r| r[:count] }
        },
        priceDistribution: {
          labels: @report[:price_distribution].map { |r| r[:label] },
          counts: @report[:price_distribution].map { |r| r[:count] }
        }
      }
    end

    # JSON embedded inside a <script> element: escape the HTML-significant characters
    # to their \\uXXXX form so free-text values (e.g. a project name) can't break out of
    # the script with </script> or be interpreted as markup. Stays valid JSON.
    def embed_json(data)
      JSON.generate(data).gsub("<", "\\u003c").gsub(">", "\\u003e").gsub("&", "\\u0026")
    end

    def chart_script
      <<~JS
        const DATA = #{embed_json(chart_data)};
        const PALETTE = ["#2563eb","#16a34a","#f59e0b","#dc2626","#7c3aed","#0891b2","#db2777"];
        const palette = n => Array.from({length: n}, (_, i) => PALETTE[i % PALETTE.length]);
        const noLegend = { plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } };

        new Chart(document.getElementById("byType"), {
          type: "doughnut",
          data: { labels: DATA.byType.labels,
                  datasets: [{ data: DATA.byType.counts, backgroundColor: palette(DATA.byType.labels.length) }] }
        });
        new Chart(document.getElementById("byBedrooms"), {
          type: "bar",
          data: { labels: DATA.byBedrooms.labels,
                  datasets: [{ label: "Số tin", data: DATA.byBedrooms.counts, backgroundColor: "#2563eb" }] },
          options: noLegend
        });
        new Chart(document.getElementById("avgPrice"), {
          type: "bar",
          data: { labels: DATA.byType.labels,
                  datasets: [{ label: "Giá TB (tỷ)", data: DATA.byType.avgPriceTy, backgroundColor: "#16a34a" }] },
          options: noLegend
        });
        new Chart(document.getElementById("priceDist"), {
          type: "bar",
          data: { labels: DATA.priceDistribution.labels,
                  datasets: [{ label: "Số tin", data: DATA.priceDistribution.counts, backgroundColor: "#f59e0b" }] },
          options: noLegend
        });
      JS
    end

    def styles
      <<~CSS
        * { box-sizing: border-box; }
        body { margin: 0; background: #f3f4f6; color: #111827;
               font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
        .wrap { max-width: 1080px; margin: 0 auto; padding: 32px 20px 64px; }
        header h1 { margin: 0; font-size: 26px; }
        header .province { margin: 4px 0 0; font-size: 16px; color: #6b7280; }
        .province-switch { display: flex; align-items: center; gap: 10px; margin-top: 14px;
                           flex-wrap: wrap; }
        .province-switch label { font-size: 13px; color: #6b7280; }
        .province-switch select { font: inherit; padding: 8px 10px; border: 1px solid #d1d5db;
                                  border-radius: 8px; background: #fff; max-width: 100%; }
        .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
                 gap: 16px; margin: 28px 0; }
        .card { background: #fff; border-radius: 12px; padding: 18px 20px;
                box-shadow: 0 1px 3px rgba(0,0,0,.08); }
        .card-value { font-size: 24px; font-weight: 700; }
        .card-label { margin-top: 4px; font-size: 13px; color: #6b7280; }
        .charts { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
                  gap: 20px; margin-bottom: 28px; }
        .chart-box { background: #fff; border-radius: 12px; padding: 18px 20px;
                     box-shadow: 0 1px 3px rgba(0,0,0,.08); }
        .chart-box h2, .block h2 { margin: 0 0 14px; font-size: 15px; font-weight: 600; }
        .block { background: #fff; border-radius: 12px; padding: 18px 20px; margin-bottom: 20px;
                 box-shadow: 0 1px 3px rgba(0,0,0,.08); }
        table { width: 100%; border-collapse: collapse; font-size: 14px; }
        th, td { text-align: left; padding: 9px 10px; border-bottom: 1px solid #e5e7eb; }
        th { background: #f9fafb; font-weight: 600; }
        tbody tr:last-child td { border-bottom: none; }
        .empty { color: #9ca3af; font-size: 13px; margin: 0; }
      CSS
    end

    # Listing-count-weighted average across the per-type averages (priced rows only).
    def weighted_avg_price(by_type)
      priced = by_type.select { |r| r[:avg_price] }
      total = priced.sum { |r| r[:count] }
      return nil if total.zero?

      priced.sum { |r| r[:avg_price] * r[:count] } / total
    end

    def h(text)
      CGI.escapeHTML(text.to_s)
    end

    def money(value)
      return "—" if value.nil?

      "#{format('%.2f', value / BILLION)} tỷ"
    end

    def price_per_m2(value)
      return "—" if value.nil?

      "#{format('%.1f', value / MILLION)} triệu/m²"
    end

    def area(value)
      return "—" if value.nil?

      "#{format('%.1f', value)} m²"
    end
  end
end
