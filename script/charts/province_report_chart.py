#!/usr/bin/env python3
"""Render a province real-estate report as a chart-rich PDF.

Contract (kept deliberately dumb — all aggregation happens in Ruby's
Reports::ProvinceReport; this script only visualizes):
  - reads the report JSON from stdin
  - writes a PDF to argv[1], or to stdout if no path is given
  - exits non-zero with a message on stderr if anything goes wrong

JSON shape (money in VND):
  {
    "province": "Hồ Chí Minh",
    "total_count": 1048,
    "by_type": [{"type","count","avg_price","avg_area"}, ...],
    "price_per_bedroom": {"condo": [{"bedrooms","count","avg_price","avg_price_per_bedroom"}], "land": [...]},
    "land_price_per_m2": {"count","avg_price_per_m2","avg_area"},
    "price_distribution": [{"label","count"}, ...]
  }
"""
import json
import sys

import matplotlib

matplotlib.use("Agg")  # headless: no display server in the Rails process
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

# DejaVu Sans is matplotlib's default and covers Vietnamese diacritics.
plt.rcParams["font.family"] = "DejaVu Sans"
plt.rcParams["axes.titlesize"] = 11
plt.rcParams["axes.titleweight"] = "bold"

BILLION = 1_000_000_000.0
MILLION = 1_000_000.0
ACCENT = "#2563eb"
ACCENT2 = "#0ea5e9"
GREEN = "#16a34a"
AMBER = "#d97706"


def _bar_labels(ax, bars, fmt):
    for bar in bars:
        height = bar.get_height()
        ax.annotate(
            fmt(height),
            (bar.get_x() + bar.get_width() / 2, height),
            ha="center", va="bottom", fontsize=7, xytext=(0, 2), textcoords="offset points",
        )


def chart_count_by_type(ax, by_type):
    rows = by_type or []
    labels = [r["type"] for r in rows]
    counts = [r["count"] for r in rows]
    bars = ax.bar(labels, counts, color=ACCENT)
    ax.set_title("Số lượng tin theo loại hình")
    ax.set_ylabel("Số tin")
    _bar_labels(ax, bars, lambda v: f"{int(v)}")
    ax.margins(y=0.18)


def chart_avg_price_by_type(ax, by_type):
    rows = [r for r in (by_type or []) if r.get("avg_price")]
    labels = [r["type"] for r in rows]
    prices = [r["avg_price"] / BILLION for r in rows]
    bars = ax.bar(labels, prices, color=GREEN)
    ax.set_title("Giá trung bình theo loại hình")
    ax.set_ylabel("tỷ VND")
    _bar_labels(ax, bars, lambda v: f"{v:.1f}")
    ax.margins(y=0.18)


def chart_condo_price_per_bedroom(ax, condo_rows):
    rows = condo_rows or []
    if not rows:
        ax.set_title("Căn hộ — giá / phòng ngủ")
        ax.text(0.5, 0.5, "Không có dữ liệu", ha="center", va="center", color="#888")
        ax.axis("off")
        return
    labels = [f"{r['bedrooms']} PN" for r in rows]
    values = [(r.get("avg_price_per_bedroom") or 0) / BILLION for r in rows]
    bars = ax.bar(labels, values, color=ACCENT2)
    ax.set_title("Căn hộ — giá trung bình / phòng ngủ")
    ax.set_ylabel("tỷ VND / phòng ngủ")
    _bar_labels(ax, bars, lambda v: f"{v:.2f}")
    ax.margins(y=0.18)


def chart_price_distribution(ax, distribution):
    rows = distribution or []
    labels = [r["label"] for r in rows]
    counts = [r["count"] for r in rows]
    bars = ax.barh(labels, counts, color=AMBER)
    ax.set_title("Phân bố tin theo khoảng giá")
    ax.set_xlabel("Số tin")
    ax.invert_yaxis()
    for bar in bars:
        width = bar.get_width()
        ax.annotate(
            f"{int(width)}",
            (width, bar.get_y() + bar.get_height() / 2),
            ha="left", va="center", fontsize=7, xytext=(3, 0), textcoords="offset points",
        )
    ax.margins(x=0.12)


def render(report, out):
    province = report.get("province", "")
    total = report.get("total_count", 0)
    land = report.get("land_price_per_m2") or {}

    fig, axes = plt.subplots(2, 2, figsize=(8.27, 11.69))  # A4 portrait
    fig.suptitle(f"Báo cáo bất động sản — {province}", fontsize=16, fontweight="bold", y=0.98)

    subtitle = f"Số tin đang hoạt động: {total}"
    if land.get("avg_price_per_m2"):
        subtitle += f"    •    Giá đất TB: {land['avg_price_per_m2'] / MILLION:.1f} triệu/m²"
    fig.text(0.5, 0.945, subtitle, ha="center", fontsize=10, color="#444")

    chart_count_by_type(axes[0][0], report.get("by_type"))
    chart_avg_price_by_type(axes[0][1], report.get("by_type"))
    chart_condo_price_per_bedroom(axes[1][0], (report.get("price_per_bedroom") or {}).get("condo"))
    chart_price_distribution(axes[1][1], report.get("price_distribution"))

    fig.tight_layout(rect=(0, 0.01, 1, 0.93))

    with PdfPages(out) as pdf:
        pdf.savefig(fig)
    plt.close(fig)


def main():
    report = json.load(sys.stdin)
    if len(sys.argv) > 1:
        render(report, sys.argv[1])
    else:
        render(report, sys.stdout.buffer)


if __name__ == "__main__":
    main()
