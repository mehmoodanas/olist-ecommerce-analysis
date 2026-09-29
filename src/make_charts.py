"""Create the report charts from the analysis result tables.

Reads reports/tables/analysis/*.csv (written by run_project.py step 7), saves
PNG charts to reports/figures/ and the exact data behind each chart to
reports/tables/figures/<chart>.csv.

Usage (after run_project.py has run the analysis step):
    python src/make_charts.py
"""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # no window needed, only files
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib.ticker import FuncFormatter, PercentFormatter  # noqa: E402

PROJECT_DIR = Path(__file__).resolve().parents[1]
ANALYSIS_DIR = PROJECT_DIR / "reports" / "tables" / "analysis"
FIGURES_DIR = PROJECT_DIR / "reports" / "figures"
CHART_DATA_DIR = PROJECT_DIR / "reports" / "tables" / "figures"

# colours: one main series colour, one emphasis colour for "late", grey for context
BLUE = "#2a78d6"
ORANGE = "#eb6834"
GREY = "#c3c2b7"
INK = "#0b0b0b"
INK_SECONDARY = "#52514e"
GRID = "#e1e0d9"
SURFACE = "#fcfcfb"

SOURCE_NOTE = "Source: Olist Brazilian E-Commerce Public Dataset (historical, 2016-2018). Values in BRL (assumed)."

plt.rcParams.update({
    "figure.facecolor": SURFACE,
    "axes.facecolor": SURFACE,
    "savefig.facecolor": SURFACE,
    "font.family": "sans-serif",
    "font.sans-serif": ["Segoe UI", "DejaVu Sans", "Arial"],
    "font.size": 11,
    "axes.titlesize": 14,
    "axes.titleweight": "bold",
    "axes.titlelocation": "left",
    "axes.labelsize": 11,
    "axes.labelcolor": INK_SECONDARY,
    "axes.edgecolor": GREY,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "axes.axisbelow": True,
    "grid.color": GRID,
    "grid.linewidth": 0.8,
    "xtick.color": INK_SECONDARY,
    "ytick.color": INK_SECONDARY,
    "text.color": INK,
})


def thousands(x, _pos=None):
    if abs(x) >= 1_000_000:
        return f"{x / 1_000_000:.1f}M"
    if abs(x) >= 1_000:
        return f"{x / 1_000:.0f}k"
    return f"{x:.0f}"


def read(name):
    path = ANALYSIS_DIR / f"{name}.csv"
    if not path.exists():
        raise FileNotFoundError(f"{path} not found. Run python run_project.py first.")
    return pd.read_csv(path)


def save(fig, name, data):
    """Save the chart PNG and the data that was plotted."""
    # placed below the figure; bbox_inches="tight" extends the image to include it
    fig.text(0.01, -0.02, SOURCE_NOTE, fontsize=8, color=INK_SECONDARY, va="top")
    fig.savefig(FIGURES_DIR / f"{name}.png", dpi=150, bbox_inches="tight")
    plt.close(fig)
    data.to_csv(CHART_DATA_DIR / f"{name}.csv", index=False)
    print(f"Saved reports/figures/{name}.png")


def month_labels(ax, months):
    """Label every third month so the axis stays readable."""
    positions = range(len(months))
    ax.set_xticks([p for p in positions if p % 3 == 0])
    ax.set_xticklabels([m for i, m in enumerate(months) if i % 3 == 0], rotation=0)


def chart_monthly_sales():
    data = read("monthly_sales")
    data = data[data["is_complete_month"] == 1][["purchase_month", "merchandise_value", "delivered_orders"]]
    months = data["purchase_month"].tolist()
    peak = data.loc[data["merchandise_value"].idxmax()]

    fig, ax = plt.subplots(figsize=(11, 5.5))
    x = range(len(data))
    ax.plot(x, data["merchandise_value"], color=BLUE, linewidth=2.2, marker="o", markersize=5)
    ax.yaxis.set_major_formatter(FuncFormatter(thousands))
    ax.set_ylim(0, data["merchandise_value"].max() * 1.15)
    ax.grid(axis="x", visible=False)
    month_labels(ax, months)

    peak_x = months.index(peak["purchase_month"])
    ax.annotate(f"Peak: {peak['purchase_month']}\n{peak['merchandise_value']:,.0f}",
                xy=(peak_x, peak["merchandise_value"]), xytext=(peak_x - 4, peak["merchandise_value"] * 1.06),
                fontsize=10, color=INK, arrowprops={"arrowstyle": "-", "color": INK_SECONDARY})

    ax.set_title("Monthly merchandise sales grew fast in 2017, then levelled off in 2018")
    ax.set_ylabel("Merchandise sales value (BRL, item prices)")
    ax.set_xlabel("Purchase month (complete months only, delivered orders)")
    save(fig, "01_monthly_sales_trend", data)


def chart_orders_and_aov():
    data = read("monthly_sales")
    data = data[data["is_complete_month"] == 1][["purchase_month", "delivered_orders", "avg_order_value"]]
    months = data["purchase_month"].tolist()
    x = range(len(data))

    # two measures with different scales -> two panels sharing the month axis
    fig, (top, bottom) = plt.subplots(2, 1, figsize=(11, 7.5), sharex=True,
                                      gridspec_kw={"height_ratios": [3, 2], "hspace": 0.25})
    top.bar(x, data["delivered_orders"], color=BLUE, width=0.7)
    top.yaxis.set_major_formatter(FuncFormatter(thousands))
    top.grid(axis="x", visible=False)
    top.set_ylabel("Delivered orders")
    first, last = data.iloc[0], data.iloc[-1]
    top.set_title(f"Delivered orders grew from {first['delivered_orders']:,} ({first['purchase_month']}) to "
                  f"{last['delivered_orders']:,} ({last['purchase_month']}); average order value stayed between "
                  f"{data['avg_order_value'].min():.0f} and {data['avg_order_value'].max():.0f}", fontsize=12.5)

    bottom.plot(x, data["avg_order_value"], color=BLUE, linewidth=2.2, marker="o", markersize=5)
    bottom.set_ylim(0, data["avg_order_value"].max() * 1.25)
    bottom.grid(axis="x", visible=False)
    bottom.set_ylabel("Average order value\n(BRL, excl. freight)")
    bottom.set_xlabel("Purchase month (complete months only)")
    month_labels(bottom, months)
    save(fig, "02_monthly_orders_and_aov", data)


def chart_top_categories(top_n=12):
    data = read("category_contribution").head(top_n)
    data = data[["category", "merchandise_value", "pct_of_sales", "items_sold"]].iloc[::-1]
    labels = data["category"].str.replace("_", " ")

    fig, ax = plt.subplots(figsize=(10, 6.5))
    ax.barh(labels, data["merchandise_value"], color=BLUE, height=0.65)
    for y, (value, pct) in enumerate(zip(data["merchandise_value"], data["pct_of_sales"])):
        ax.text(value, y, f"  {pct:.1f}%", va="center", fontsize=10, color=INK_SECONDARY)
    ax.xaxis.set_major_formatter(FuncFormatter(thousands))
    ax.set_xlim(0, data["merchandise_value"].max() * 1.15)
    ax.grid(axis="y", visible=False)
    ax.set_title(f"Top {top_n} categories by merchandise sales (labels = share of all sales)")
    ax.set_xlabel("Merchandise sales value (BRL, delivered orders)")
    save(fig, "03_top_categories", data.iloc[::-1])


def chart_state_sales(top_n=10):
    states = read("state_performance")
    top = states.head(top_n)[["customer_state", "merchandise_value", "pct_of_sales", "avg_order_value", "delivered_orders"]]
    other = states.iloc[top_n:]
    other_row = pd.DataFrame([{
        "customer_state": f"Other {len(other)} states",
        "merchandise_value": other["merchandise_value"].sum(),
        "pct_of_sales": round(other["pct_of_sales"].sum(), 2),
        "avg_order_value": round(other["merchandise_value"].sum() / other["delivered_orders"].sum(), 2),
        "delivered_orders": other["delivered_orders"].sum(),
    }])
    data = pd.concat([top, other_row], ignore_index=True)
    plot = data.iloc[::-1]
    colors = [GREY if s.startswith("Other") else BLUE for s in plot["customer_state"]]

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.barh(plot["customer_state"], plot["merchandise_value"], color=colors, height=0.65)
    for y, (value, pct, orders) in enumerate(zip(plot["merchandise_value"], plot["pct_of_sales"], plot["delivered_orders"])):
        ax.text(value, y, f"  {pct:.1f}%  ({orders:,} orders)", va="center", fontsize=10, color=INK_SECONDARY)
    ax.xaxis.set_major_formatter(FuncFormatter(thousands))
    ax.set_xlim(0, data["merchandise_value"].max() * 1.35)
    ax.grid(axis="y", visible=False)
    ax.set_title("São Paulo (SP) alone accounts for 38% of merchandise sales")
    ax.set_xlabel("Merchandise sales value (BRL, delivered orders, by customer state)")
    save(fig, "04_sales_by_state", data)


def chart_late_by_state():
    data = read("late_by_state")
    overall = read("delivery_overall").iloc[0]
    data = data[data["meets_min_volume"] == 1][["customer_state", "valid_deliveries", "late_rate_pct", "avg_delivery_days"]]
    data = data.sort_values("late_rate_pct")

    fig, ax = plt.subplots(figsize=(10, 7))
    colors = [ORANGE if rate > overall["late_rate_pct"] else BLUE for rate in data["late_rate_pct"]]
    ax.barh(data["customer_state"], data["late_rate_pct"], color=colors, height=0.65)
    for y, (rate, n) in enumerate(zip(data["late_rate_pct"], data["valid_deliveries"])):
        ax.text(rate, y, f" {rate:.1f}%  (n={n:,})", va="center", fontsize=9.5, color=INK_SECONDARY,
                bbox={"facecolor": SURFACE, "edgecolor": "none", "pad": 1}, zorder=3)
    ax.axvline(overall["late_rate_pct"], color=INK_SECONDARY, linestyle="--", linewidth=1, zorder=1)
    ax.text(overall["late_rate_pct"], len(data) - 0.4, f" all states {overall['late_rate_pct']:.2f}%",
            fontsize=9.5, color=INK_SECONDARY, va="bottom")
    ax.xaxis.set_major_formatter(PercentFormatter(decimals=0))
    ax.set_xlim(0, data["late_rate_pct"].max() * 1.4)
    ax.grid(axis="y", visible=False)
    ax.set_title("Late-delivery rate by customer state (states with 500+ deliveries)")
    ax.set_xlabel("Share of deliveries after the estimated delivery date  (orange = above the overall rate)")
    save(fig, "05_late_delivery_by_state", data)


def chart_reviews_by_delivery():
    data = read("review_by_days_vs_estimate")
    data["label"] = data["delivery_band"].str.split(": ").str[1]
    data = data[["delivery_band", "label", "reviewed_orders", "avg_review_score", "pct_1_or_2_stars"]]
    summary = read("review_late_vs_on_time").set_index("delivery_status")
    late, on_time = summary.loc["late"], summary.loc["on time"]

    fig, ax = plt.subplots(figsize=(11, 6))
    colors = [ORANGE if "late" in label else BLUE for label in data["label"]]
    x = range(len(data))
    ax.bar(x, data["avg_review_score"], color=colors, width=0.65)
    for i, (score, n) in enumerate(zip(data["avg_review_score"], data["reviewed_orders"])):
        ax.text(i, score + 0.06, f"{score:.2f}\nn={n:,}", ha="center", va="bottom", fontsize=9, color=INK_SECONDARY)
    ax.set_xticks(list(x))
    ax.set_xticklabels(data["label"].str.replace(" days", "\ndays").str.replace("on the ", "on the\n"), fontsize=9.5)
    ax.set_ylim(0, 5.5)
    ax.set_yticks([0, 1, 2, 3, 4, 5])
    ax.grid(axis="x", visible=False)
    ax.set_title(f"Late orders average {late['avg_review_score']:.2f} stars vs {on_time['avg_review_score']:.2f} "
                 "for on-time orders (association, not proof of cause)")
    ax.set_ylabel("Average review score (1-5 stars)")
    ax.set_xlabel("Delivery date compared with the estimated delivery date  (orange = late)")
    save(fig, "06_review_score_by_delivery_timing", data)


def make_charts():
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    CHART_DATA_DIR.mkdir(parents=True, exist_ok=True)
    chart_monthly_sales()
    chart_orders_and_aov()
    chart_top_categories()
    chart_state_sales()
    chart_late_by_state()
    chart_reviews_by_delivery()


if __name__ == "__main__":
    make_charts()
