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
      condo_by_project_section
      price_per_bedroom_section
      land_section
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

    # Condos grouped by project: number of units, 1- & 2-bedroom average price, price/m².
    # (The HTML report shows these one project at a time via a dropdown; the PDF lists all.)
    def condo_by_project_section
      projects = @report[:condo_by_project]
      section_title("Căn hộ theo dự án")
      if projects.empty?
        @pdf.text "Không có dữ liệu căn hộ theo dự án.", size: 9, color: "888888"
        @pdf.move_down 8
        return
      end

      data = [ [ "Dự án", "Số căn", "Giá TB 1PN", "Giá TB 2PN", "Giá / m²" ] ]
      projects.each do |row|
        data << [
          row[:project_name].to_s,
          row[:count].to_s,
          money(row[:avg_price_1bed]),
          money(row[:avg_price_2bed]),
          price_per_m2(row[:avg_price_per_m2])
        ]
      end
      render_table(data)
    end

    def price_per_bedroom_section
      { condo: "Căn hộ — giá theo số phòng ngủ", land: "Đất — giá theo số phòng ngủ" }.each do |key, label|
        rows = @report[:price_per_bedroom][key]
        section_title(label)
        if rows.empty?
          @pdf.text "Không có dữ liệu phòng ngủ.", size: 9, color: "888888"
          @pdf.move_down 8
          next
        end

        data = [ [ "Phòng ngủ", "Số lượng", "Giá TB", "Giá / phòng ngủ" ] ]
        rows.each do |row|
          data << [ row[:bedrooms].to_s, row[:count].to_s, money(row[:avg_price]), money(row[:avg_price_per_bedroom]) ]
        end
        render_table(data)
      end
    end

    def land_section
      land = @report[:land_price_per_m2]
      section_title("Đất — giá trên mỗi m²")
      if land[:count].zero?
        @pdf.text "Không có tin đất.", size: 9, color: "888888"
        @pdf.move_down 8
        return
      end

      data = [
        [ "Số tin", land[:count].to_s ],
        [ "Diện tích TB", area(land[:avg_area]) ],
        [ "Giá / m² (TB)", price_per_m2(land[:avg_price_per_m2]) ]
      ]
      render_table(data)
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
