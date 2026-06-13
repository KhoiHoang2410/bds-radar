require "prawn"
require "prawn/table"

module Reports
  # Renders a ProvinceReport data hash into a PDF (binary string).
  # Prawn's built-in fonts are Latin-1 only, so we ship a Unicode TTF (DejaVu Sans)
  # to render Vietnamese diacritics correctly.
  class ProvinceReportPdf
    FONT_DIR = Rails.root.join("app/assets/fonts")
    BILLION = 1_000_000_000.0
    MILLION = 1_000_000.0

    def self.call(report)
      new(report).render
    end

    def initialize(report)
      @report = report
      @pdf = Prawn::Document.new(page_size: "A4", margin: 40)
      install_unicode_font
    end

    def render
      heading
      summary_section
      price_per_bedroom_section
      land_by_ward_area_section
      price_distribution_section
      @pdf.render
    end

    private

    def install_unicode_font
      regular = FONT_DIR.join("DejaVuSans.ttf")
      bold = FONT_DIR.join("DejaVuSans-Bold.ttf")
      return unless File.exist?(regular)

      @pdf.font_families.update(
        "DejaVu" => { normal: regular.to_s, bold: (bold.exist? ? bold.to_s : regular.to_s) }
      )
      @pdf.font("DejaVu")
    end

    def heading
      @pdf.text "Báo cáo bất động sản", size: 20, style: :bold
      @pdf.text @report[:province].name, size: 14
      @pdf.text "Số tin đang hoạt động: #{@report[:total_count]}", size: 10
      @pdf.move_down 16
    end

    def summary_section
      section_title("Tổng quan theo loại hình")
      data = [ [ "Loại", "Số lượng", "Giá TB", "Diện tích TB" ] ]
      @report[:by_type].each do |row|
        data << [ row[:type], row[:count].to_s, money(row[:avg_price]), area(row[:avg_area]) ]
      end
      render_table(data)
    end

    # Only condos are analysed by bedroom count — land is analysed by area
    # (land_by_area_section), since land listings rarely carry a bedroom count.
    def price_per_bedroom_section
      rows = @report[:price_per_bedroom][:condo]
      section_title("Căn hộ — giá theo số phòng ngủ")
      if rows.empty?
        @pdf.text "Không có dữ liệu phòng ngủ.", size: 9, color: "888888"
        @pdf.move_down 8
        return
      end

      data = [ [ "Phòng ngủ", "Số lượng", "Giá TB", "Giá / phòng ngủ" ] ]
      rows.each do |row|
        data << [ row[:bedrooms].to_s, row[:count].to_s, money(row[:avg_price]), money(row[:avg_price_per_bedroom]) ]
      end
      render_table(data)
    end

    # Land analysed per ward, each ward broken into area buckets (count, avg price, price/m²).
    def land_by_ward_area_section
      section_title("Đất — phân tích theo phường & diện tích")
      wards = @report[:land_by_ward_area]
      if wards.empty?
        @pdf.text "Không có tin đất.", size: 9, color: "888888"
        @pdf.move_down 8
        return
      end

      wards.each do |ward|
        @pdf.text "#{ward[:ward]} (#{ward[:count]} tin)", size: 11, style: :bold
        @pdf.move_down 4
        data = [ [ "Khoảng diện tích", "Số tin", "Giá TB", "Giá / m²" ] ]
        ward[:buckets].each do |b|
          data << [ b[:label], b[:count].to_s, money(b[:avg_price]), price_per_m2(b[:avg_price_per_m2]) ]
        end
        render_table(data)
      end
    end

    def price_distribution_section
      section_title("Số lượng tin theo khoảng giá")
      data = [ [ "Khoảng giá", "Số lượng" ] ]
      @report[:price_distribution].each { |row| data << [ row[:label], row[:count].to_s ] }
      render_table(data)
    end

    def section_title(text)
      @pdf.move_down 6
      @pdf.text text, size: 12, style: :bold
      @pdf.move_down 4
    end

    def render_table(data)
      @pdf.table(data, width: @pdf.bounds.width, cell_style: { size: 9, padding: 5 }) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = "EEEEEE"
      end
      @pdf.move_down 12
    end

    # 7_500_000_000 → "7.5 tỷ"; nil → "—".
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
