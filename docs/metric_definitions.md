# Metric Definitions

Every metric in this project is defined here: the formula, the grain it is calculated at, the date it is based on, what is excluded and its known limitations. The SQL is in [`sql/analysis/`](../sql/analysis/) and runs on the reporting models in [`sql/models/`](../sql/models/). The example values are the executed results saved in [`reports/tables/analysis/`](../reports/tables/analysis/).

Money values have no currency in the source files and are assumed to be Brazilian reais (BRL). All results describe the historical period in the dataset (2016-09 to 2018-10), not Olist today.

## Shared rules

| Rule | Detail |
|---|---|
| Included orders for sales | `status_group = 'delivered'` (order status `delivered`): 96,478 orders. In-progress orders (1,729) could still be canceled, and canceled/unavailable orders (1,234) are not completed sales. |
| Included orders for delivery | `is_valid_delivery = 1`: delivered status, delivery date present and not before purchase: 96,470 orders. |
| Date basis | Purchase date (`order_purchase_timestamp`) for all monthly figures, because it exists for every order and is when the demand happened. |
| Complete months | 2017-01 to 2018-08. The boundary months 2016-09, 2016-10, 2016-12, 2018-09 and 2018-10 are incomplete (2016-11 has no orders) and are excluded from growth. |
| Customer | A person is `customer_unique_id`. `customer_id` changes with every order and is never used to count customers. |
| Minimum volumes | Groups with fewer than 500 orders (states) or 100 reviewed orders (review bands) are not ranked on averages or rates. |

## Merchandise sales value

- **Formula:** `SUM(price)` of order items in delivered orders.
- **Grain:** item, summed to order, month, category or state.
- **What it is not:** it is **not** Olist's company revenue. Olist is a marketplace; its revenue would be commissions and fees, which are not in the data. It is the value of goods sold through the platform (similar to gross merchandise value before freight).
- **Freight** (`SUM(freight_value)`) is reported separately and never added in. Over the whole period freight equals 16.63% of merchandise value (2,198,275.64 vs 13,221,498.11).
- **Result:** 13,221,498.11 across 96,478 delivered orders.

## Payment value (kept separate)

- **Formula:** `SUM(payment_value)` from payment records, aggregated to one row per order before joining.
- It should equal merchandise + freight. Checked in `payment_vs_merchandise`: for **96,099 of 96,477 delivered orders with a payment record (99.61%)** it matches to the cent. 285 orders paid more and 93 paid less. The net difference is +2,831.48, of which +2,892.60 comes from credit-card orders paid in instalments, which fits with instalment charges, although the data does not say so. One delivered order has no payment record.
- Because payment includes freight and possible charges, it is not used as the sales measure.

## Order count

- **Formula:** `COUNT(*)` of orders with `status_group = 'delivered'`, by purchase month.
- `all_orders` in `model_monthly_sales` also shows orders of every status, so the excluded share is visible.

## Average order value (AOV)

- **Formula:** merchandise sales value / delivered orders. Freight excluded.
- **Grain:** order.
- **Result:** mean 137.04, median 86.57. Order values are skewed: 0.94% of orders (1,000 and over) make up 11.10% of sales, so the median is reported next to the mean. The median is the middle value (the lower of the two middle values when the count is even).
- **Limitation:** a single order can contain items from several sellers; AOV is per order, not per seller.

## Monthly growth

- **Formula:** `(value this month − value previous month) / value previous month × 100`, using `LAG()` over complete months only.
- **Grain:** month. Calculated for both merchandise value and delivered orders.
- **Exclusions:** incomplete boundary months. 2017-01 is the first complete month, so it has no growth value.
- **Limitation:** monthly growth is volatile (from −26.5% to +109.5% across the 19 comparisons), partly from seasonality such as the November 2017 peak. A year-on-year comparison of the same months (January–August) is also given: merchandise value rose from 2,993,456.13 in 2017 to 7,218,125.12 in 2018 (+141.1%).
- **Late months:** orders placed in the last weeks of the data that were not yet delivered when the data was extracted are not counted as delivered, so the last complete months may be slightly understated.

## Repeat-customer rate

- **Formula:** people with 2 or more delivered orders / people with at least 1 delivered order.
- **Grain:** person (`customer_unique_id`).
- **Result:** 2,801 of 93,358 people (3.00%). 829 of these placed their second order on the same day as the first (for example a split basket); excluding them the rate is 2.11%.
- **Limitations:**
  - It measures repeat purchasing **within the observed data only**, not lifetime retention.
  - Observation time is unequal. A person who first bought in 2017-Q1 could be followed for about 549 days on average; one who first bought in 2018-Q3 only about 30 days. The rate by first-purchase quarter falls from 3.88% (2017-Q2) to 0.60% (2018-Q3) mainly for this reason.
  - A fairer fixed-window measure is also reported: of 55,907 people who could be followed for at least 180 days, 1.92% placed another order on a later day within 180 days.
  - Follow-up ends at the last delivered purchase (2018-08-29).

## Delivery time

- **Formula:** `julianday(delivered_ts) − julianday(purchase_ts)`, in days with decimals.
- **Grain:** order. Only `is_valid_delivery = 1`.
- **Why purchase to delivery:** the carrier hand-over date is unreliable for at least 189 orders (see [data quality report](../reports/data_quality.md)), while purchase and delivery timestamps are always in a possible order.
- **Result:** mean 12.56 days, median 10.22 days.
- **Limitation:** orders not delivered by the time the data was extracted are not included, so recent months can look faster than they were.

## Late-delivery rate

- **Formula:** orders where the delivery **date** is after the estimated delivery **date** / valid deliveries.
- **Why dates, not timestamps:** the estimated delivery date has no time (it is always midnight). Comparing full timestamps would mark a delivery at 15:00 on the promised day as late. With the date rule 6,534 orders are late; with the timestamp rule it would be 7,826. The difference is the 1,292 orders delivered on the estimated day.
- **Result:** 6.77% late (6,534 of 96,470). Late orders arrive on average 10.62 days after the estimate.
- **Limitation:** the estimate is the date shown to the customer at purchase; the data does not say how it was calculated.

## Review score

- **Formula:** `AVG(review_score)` over orders that have a review. One review per order: when an order has 2–3 reviews (547 orders), the latest answered review is used.
- **Grain:** order.
- **Coverage:** 99.33% of delivered orders have a review (95,832 of 96,478). Orders without a review are excluded from averages, not treated as zero.
- **Sample sizes** are reported with every comparison: 89,443 reviewed on-time orders vs 6,381 reviewed late orders.
- **Limitation:** review scores are observational. Late orders may differ from on-time orders in other ways (region, seller, product), so the gap between them is an association, not proof of cause. The within-state comparison (`review_late_vs_on_time_by_state`) shows the gap in every state with at least 100 reviewed late orders, which makes a pure regional explanation less likely but does not rule out other factors.

## Category metrics

- **Sales share:** category merchandise value / total merchandise value (delivered). Adds up to 100%.
- **Orders containing a category:** does **not** add up. An order with items from two categories is counted in both. Across delivered orders the category order counts sum to 97,276, compared with 96,478 actual orders (780 orders contain 2 or more categories).
- `unknown` (products with no category) is its own group: 1.29% of delivered merchandise value.

## State metrics

- **State** = the customer's state on the order (`customer_state`). For people, the state of their first order.
- Sales share adds up across states; averages and rates are only ranked for states with at least 500 orders or deliveries.
