class ReportsController < ApplicationController
  # GET /provinces/:province_id/report(.html|.pdf)
  # A per-province real-estate analytics report — listing counts by type and by
  # bedroom count, average prices, condo/land price-per-bedroom, land price/m², and a
  # price-range distribution. HTML (default; interactive Chart.js charts) or PDF.
  def show
    province = Province.find(params[:province_id])
    report = Reports::ProvinceReport.call(province)

    respond_to do |format|
      format.html do
        scheduled = Province.scheduled.order(:name)
        render html: Reports::ProvinceReportHtml.call(report, provinces: scheduled).html_safe
      end
      format.pdf do
        send_data Reports::ProvinceReportPdf.call(report),
                  filename: "bds-report-province-#{province.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end
end
