class ReportsController < ApplicationController
  # GET /provinces/:province_id/report.pdf
  # Renders a per-province real-estate analytics report as a PDF: listing counts by
  # type, condo/land price-per-bedroom, land price/m², and a price-range distribution.
  def show
    province = Province.find(params[:province_id])
    report = Reports::ProvinceReport.call(province)
    pdf = Reports::ProvinceReportPdf.call(report)

    send_data pdf,
              filename: "bds-report-province-#{province.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  # GET /provinces/:province_id/report/charts.pdf
  # Same figures as #show, but rendered as matplotlib charts (Python subprocess).
  def charts
    unless Reports::ProvinceReportChartPdf.available?
      return render_errors({ charts: [ "chart runtime unavailable" ] }, status: :service_unavailable)
    end

    province = Province.find(params[:province_id])
    report = Reports::ProvinceReport.call(province)
    pdf = Reports::ProvinceReportChartPdf.call(report)

    send_data pdf,
              filename: "bds-report-province-#{province.id}-charts.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end
end
