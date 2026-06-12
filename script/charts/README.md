# Chart reports (Python / matplotlib)

`province_report_chart.py` renders a province report as a chart-rich PDF. It's a
pure visualizer: all aggregation happens in Ruby (`Reports::ProvinceReport`), which
hands this script the report JSON on **stdin** and reads the PDF back from **stdout**
(or a file path as `argv[1]`). The Rails side is `Reports::ProvinceReportChartPdf`,
exposed at `GET /provinces/:province_id/report/charts`.

## Setup

```sh
python3 -m venv script/charts/.venv
script/charts/.venv/bin/pip install -r script/charts/requirements.txt
```

The Ruby service resolves the interpreter in this order:

1. `CHARTS_PYTHON` env var (absolute path to a python binary)
2. the bundled venv at `script/charts/.venv/bin/python`
3. a bare `python3` on `PATH`

If none can `import matplotlib`, the endpoint responds `503` instead of erroring.

## Smoke test

```sh
echo '{"province":"Demo","total_count":3,
  "by_type":[{"type":"condo","count":2,"avg_price":5e9,"avg_area":60}],
  "price_per_bedroom":{"condo":[{"bedrooms":2,"count":2,"avg_price":5e9,"avg_price_per_bedroom":2.5e9}],"land":[]},
  "land_price_per_m2":{"count":0,"avg_price_per_m2":null,"avg_area":null},
  "price_distribution":[{"label":"< 1 tỷ","count":1},{"label":"≥ 20 tỷ","count":0}]}' \
  | script/charts/.venv/bin/python script/charts/province_report_chart.py /tmp/charts.pdf
```
