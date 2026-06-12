require "open3"
require "json"

module Reports
  # Renders a ProvinceReport into a chart-rich PDF by shelling out to a Python
  # (matplotlib) script. Ruby owns all aggregation (ProvinceReport); Python only
  # visualizes — we hand it JSON on stdin and read the PDF bytes back from stdout.
  #
  # The interpreter is resolved from, in order: CHARTS_PYTHON env var, the bundled
  # virtualenv (script/charts/.venv), then a bare `python3`. Provision the venv with:
  #   python3 -m venv script/charts/.venv
  #   script/charts/.venv/bin/pip install -r script/charts/requirements.txt
  class ProvinceReportChartPdf
    SCRIPT = Rails.root.join("script/charts/province_report_chart.py")
    VENV_PYTHON = Rails.root.join("script/charts/.venv/bin/python")

    class GenerationError < StandardError; end

    def self.call(report)
      new(report).render
    end

    # True when the interpreter resolves and can import matplotlib — lets callers
    # (and specs) degrade gracefully instead of 500-ing when charts aren't provisioned.
    def self.available?
      out, status = Open3.capture2e(python, "-c", "import matplotlib")
      status.success?
    rescue StandardError => e
      Rails.logger.warn("[charts] interpreter unavailable: #{e.message} #{out}")
      false
    end

    def self.python
      return ENV["CHARTS_PYTHON"] if ENV["CHARTS_PYTHON"].present?

      File.executable?(VENV_PYTHON.to_s) ? VENV_PYTHON.to_s : "python3"
    end

    def initialize(report)
      @report = report
    end

    def render
      stdout, stderr, status = Open3.capture3(
        self.class.python, SCRIPT.to_s, stdin_data: payload, binmode: true
      )
      raise GenerationError, "chart script failed (#{status.exitstatus}): #{stderr}" unless status.success?
      raise GenerationError, "chart script produced no output" if stdout.empty?

      stdout
    end

    private

    # Flatten the report to the JSON shape province_report_chart.py expects.
    def payload
      {
        province: @report[:province].name,
        total_count: @report[:total_count],
        by_type: @report[:by_type],
        price_per_bedroom: @report[:price_per_bedroom],
        land_price_per_m2: @report[:land_price_per_m2],
        price_distribution: @report[:price_distribution]
      }.to_json
    end
  end
end
