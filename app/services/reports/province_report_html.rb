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

    def self.call(report)
      new(report).render
    end

    def initialize(report)
      @report = report
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
          #{land_by_district_ward_section}
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
        </header>
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

    # Only condos are analysed by bedroom count — land is analysed by area within each
    # ward (see land_by_district_ward_section), since land rarely carries a bedroom count.
    def price_per_bedroom_tables
      rows = @report[:price_per_bedroom][:condo].map do |row|
        [ row[:bedrooms].to_s, row[:count].to_s, money(row[:avg_price]), money(row[:avg_price_per_bedroom]) ]
      end
      table("Căn hộ — giá theo số phòng ngủ", [ "Phòng ngủ", "Số lượng", "Giá TB", "Giá / phòng ngủ" ], rows,
            empty: "Không có dữ liệu phòng ngủ.")
    end

    # Land analysed by district (e.g. "Thành phố Nha Trang") → ward → area buckets
    # (count, avg price, price/m²). An empty-state note when the province has no land.
    def land_by_district_ward_section
      districts = @report[:land_by_district_ward]
      inner =
        if districts.empty?
          %(<p class="empty">Không có tin đất.</p>)
        else
          districts.map { |district| land_district_block(district) }.join
        end
      %(<section class="block"><h2>Đất — phân tích theo khu vực &amp; diện tích</h2>#{inner}</section>)
    end

    def land_district_block(district)
      wards = district[:wards].map { |ward| land_ward_block(ward) }.join
      %(<div class="district-block"><h3>#{h(district[:district])} <span class="loc-count">(#{district[:count]} tin)</span></h3>#{wards}</div>)
    end

    def land_ward_block(ward)
      head = "<thead><tr><th>Khoảng diện tích</th><th>Số tin</th><th>Giá TB</th><th>Giá / m²</th></tr></thead>"
      body = ward[:buckets].map do |b|
        "<tr><td>#{b[:label]}</td><td>#{b[:count]}</td><td>#{money(b[:avg_price])}</td>" \
          "<td>#{price_per_m2(b[:avg_price_per_m2])}</td></tr>"
      end.join
      %(<div class="ward-block"><h4>#{h(ward[:ward])} <span class="loc-count">(#{ward[:count]} tin)</span></h4>) +
        %(<table>#{head}<tbody>#{body}</tbody></table></div>)
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
        .district-block { margin-top: 24px; padding-top: 16px; border-top: 2px solid #e5e7eb; }
        .district-block:first-of-type { margin-top: 6px; padding-top: 0; border-top: none; }
        .district-block > h3 { margin: 0 0 6px; font-size: 16px; font-weight: 700; }
        .ward-block { margin: 14px 0 0 14px; }
        .ward-block h4 { margin: 0 0 6px; font-size: 13px; font-weight: 600; }
        .loc-count { color: #6b7280; font-weight: 400; font-size: 13px; }
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
