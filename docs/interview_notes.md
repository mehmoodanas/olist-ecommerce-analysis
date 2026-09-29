# Interview Notes

Preparation notes for discussing this project. Every number here comes from the executed analysis; see [reports/findings.md](../reports/findings.md) and [docs/metric_definitions.md](metric_definitions.md).

## Five-minute walkthrough

**1. The question (30 seconds).** I took the role of an analyst supporting an e-commerce operations manager. The questions were: how are sales and orders changing, which categories and regions matter most, how does order value behave, do customers come back, where are deliveries late, and how does delivery timing relate to review scores.

**2. The data (45 seconds).** I used the public Olist dataset from Kaggle: about 99,000 orders from a Brazilian marketplace between 2016 and 2018, spread over eight related tables (orders, items, payments, reviews, customers, products, sellers, category names). Before cleaning anything I profiled it: row counts, key uniqueness, missing values, date ranges and relationships. Two things stood out early. First, `customer_id` is created per order, so real customers have to be counted with `customer_unique_id`. Second, items, payments and reviews all have many rows per order, and joining them directly inflated payment totals by 26.9%.

**3. Cleaning (45 seconds).** Cleaning was done in SQL and deleted nothing. Instead I grouped order statuses (delivered, in progress, not fulfilled) and added flags for problems: for example 166 orders with a carrier date before the purchase, 8 delivered orders without a delivery date, and 610 products with no category. Each metric then states which records it includes. A check stops the pipeline if raw and clean row counts differ.

**4. Models and validation (45 seconds).** I built five reporting models: order level, item level, customer, monthly sales and delivery by state. Items, payments and reviews are aggregated to one row per order before they are joined. For the 547 orders with more than one review, I keep the latest answered review. 41 validation queries check keys, required fields, orphan rows, row counts and money totals before and after joins, and timestamp order. `run_project.py` rebuilds everything from the CSVs and stops if any check fails.

**5. Results (90 seconds).**
- January–August sales rose 141.1% from 2017 to 2018, but monthly sales were flat within 2018, and average order value stayed between 124 and 149. Growth came from more orders, not bigger ones.
- SP accounts for 38.33% of merchandise sales; the top 10 of 74 categories make up 62.43%.
- 6.77% of deliveries were late. Among states with 500+ deliveries this ranges from 4.04% to 17.43%, and RJ has 22.9% of all late deliveries while having 12.8% of deliveries. Cross-state orders were late 8.14% of the time versus 4.56% within the same state.
- Late orders average 2.27 stars against 4.29 for on-time orders, and the gap appears within every state I checked.
- Only 3.00% of customers placed a second delivered order in the data, and 1.92% within a fixed 180-day window.

**6. Recommendations and limits (45 seconds).** I recommended focusing delivery improvements on RJ, the high-late northeastern states and cross-state routes; monitoring the late rate monthly around peaks; and testing a repeat-purchase programme with a control group. I was careful to call the review result an association: late orders might differ in other ways. The data is historical, so it describes 2016–2018, not Olist today.

## Likely interview questions

**1. Why did you use SQLite instead of just pandas?**
The main work (cleaning, joins, aggregation, validation) is naturally expressed in SQL, and SQL is what most analyst roles use daily. SQLite needs no server, so the whole project runs locally from one command. Python loads the CSVs, runs the SQL files in order and creates charts from the results.

**2. How did you avoid double counting when joining tables?**
Items, payments and reviews each have several rows per order. I aggregated each one to one row per order in a CTE first, then `LEFT JOIN`ed them to orders. Validation queries then compare totals before and after: the sum of item prices is 13,591,643.70 in both the clean items table and the order model, and payment value is 16,008,872.12 in both. In the raw data, joining items directly to payments turned 16.0M of payments into 20.3M.

**3. Why only delivered orders for sales?**
Orders that are still in progress could be canceled, and canceled or unavailable orders are not completed sales. I kept them in the models with a status group so the exclusion is visible: 96,478 of 99,441 orders are delivered, 1,729 in progress and 1,234 not fulfilled.

**4. How did you define a late delivery, and why?**
Late means the delivery date is after the estimated delivery date. The estimate has no time part, so comparing full timestamps would count a parcel delivered at 3 pm on the promised day as late. That rule would give 7,826 late orders instead of 6,534; the difference is exactly the 1,292 orders delivered on the estimated day.

**5. Why is the repeat-customer rate so low, and can you trust it?**
Counting by `customer_unique_id`, 3.00% of customers placed a second delivered order. The number has two caveats. It only covers the data period, and customers who first bought in 2018 had little time to return: the rate falls from 3.88% for 2017-Q2 first buyers to 0.60% for 2018-Q3. So I also report a fixed 180-day window for customers who could be followed that long (1.92%). Also, 829 of the 2,801 repeat customers placed the second order on the same day, which is more like a split basket than a return.

**6. Does late delivery cause bad reviews?**
The data can't prove that. It shows a strong association: 2.27 versus 4.29 stars, and 62.42% of late-order reviews are 1 or 2 stars compared with 9.27%. I checked the gap within each state so it isn't just a regional difference, and the score falls step by step the later the order is. But late orders could also differ in product quality or seller. To test cause you would need an experiment, for example changing delivery promises for some routes.

**7. How did you handle outliers?**
Item prices are skewed (median 74.99, maximum 6,735.00, 844 items above 1,000). I did not remove them because they are real sales, and removing them would understate sales. Instead I report the median order value (86.57) next to the mean (137.04).

**8. What would you do with more time?**
Look at seller-level delivery performance, use the geolocation file to measure distance and see how much of the state difference it explains, investigate the late-delivery spike in February–March 2018 (14.13% and 18.96%), and analyse the review text.

**9. What was the hardest data problem?**
Reviews. `review_id` is not unique on its own (789 review ids are linked to 2 or 3 orders), and 547 orders have more than one review, with different scores in 202 of them. I needed a clear rule, so I keep the latest answered review per order and store the review count. A validation check confirms the model has exactly one review for every order that has any review.

**10. How do you know your numbers are right?**
Three ways. The pipeline runs 41 validation checks and stops if any fail; I also tested that it really stops by inserting a duplicate row. Totals are reconciled between layers (clean tables, models, monthly summary, customer summary). And I cross-checked independent measures, for example payment value matches merchandise plus freight to the cent for 99.61% of delivered orders.

## Key SQL decisions

| Decision | Why |
|---|---|
| Flag, don't delete | Keeps totals traceable back to the raw files; each metric chooses what to include. |
| Aggregate before joining | One-to-many joins multiply rows; totals are checked before and after. |
| `ROW_NUMBER()` to pick one review per order | Deterministic rule (latest answered, then review id); no ties exist. |
| `ROW_NUMBER()` for the main payment type | Replaced a correlated subquery that would have scanned all payments for each order. |
| `LAG()` for month-over-month growth, complete months only | Boundary months with 1–324 orders would create meaningless growth figures. |
| Date comparison for lateness | The estimate has no time component. |
| Purchase-to-delivery time instead of carrier dates | Carrier dates are impossible for at least 189 orders. |
| `customer_unique_id` for customers | `customer_id` changes with every order. |
| Follow-up ends at the last delivered purchase (2018-08-29) | Later orders were never delivered, so they cannot count as repeat purchases. |
| Minimum volumes (500 orders per state, 100 reviews per band) | Small groups give unstable rates. |

## CV bullet points

- Built a reproducible SQL (SQLite) and Python pipeline that cleans, models and validates about 99,000 e-commerce orders across eight tables, with 41 automated data checks that stop the run on failure.
- Defined and documented business metrics (merchandise sales, AOV, month-over-month growth, repeat-customer rate, late-delivery rate, review score) and wrote 26 SQL analysis queries using CTEs and window functions.
- Found that late deliveries (6.77% overall, up to 17.43% by state) were associated with average review scores of 2.27 versus 4.29 on time, and presented the results in charts and a written report with three evidence-based recommendations.
