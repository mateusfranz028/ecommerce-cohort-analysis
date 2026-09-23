# Ecommerce Cohort Analysis
<img width="1475" height="830" alt="gif dashboard" src="https://github.com/user-attachments/assets/437dd4da-bd9e-4df5-b151-6d518f4ea2d3" />

## Summary
This project implements a scalable cohort analysis pipeline:
1. **Data Modeling & DDL in PostgreSQL:** Raw transaction records are aggregated into a standardized dimensional analytical view (`vw_cohort_analysis`), establishing customer first-purchase timestamps, cohort assignment, and transactional intervals.
2. **Semantic Modeling & DAX Intelligence in Power BI:** Ingestion of the aggregated pipeline, configuration of a dedicated calendar dimension (`dCalendar`), and implementation of non-linear measures to assess cohort retention decay and cumulative Lifetime Value.
3. **Executive Reporting:** An interactive, single-page dashboard displaying core financial benchmarks, retention decay heatmaps, cumulative LTV maturation curves, and MoM financial trends.

## Project Files
[VW Cohort Analysis (SQL File)](vw_cohort_analysis.sql)

[Cohort Analysis Dashboard (Power BI File)](ecommerce_cohort_analysis.pbix)


## Skills Used

### <img width="25" height="25" alt="postgresql" src="https://github.com/user-attachments/assets/2fa38274-43fe-453e-bc8b-68914e990da7" /> PostgreSQL Skills
* **Common Table Expressions**
* **Multi-Table Joins & Filtering**
* **Date Manipulation & Calculations**
* **DDL & View Creation**

---

### <img width="25" height="25" alt="powerbi" src="https://github.com/user-attachments/assets/09bb7cf9-7119-485d-81e5-82b95d0c34a4" /> Power BI & DAX Skills
* **Semantic & Star Schema Modeling**
* **Advanced DAX Formulas**
* **Cohort Heatmap Visualization**
* **Executive Dashboard Design**

---

### <img width="25" height="25" alt="data-eyes" src="https://github.com/user-attachments/assets/3813c761-9e14-4254-8328-af7460aefb96" /> Business & Cohort Analytics Skills
* **Cohort Retention Analysis**
* **Unit Economics & LTV Modeling**
* **Month-over-Month (MoM) Growth**
* **Cross-Validation & Auditing**



## Key Performance Benchmarks

| Benchmark Metric | Value | Business Definition |
| :--- | :---: | :--- |
| **Total Unique Customers** | **93,358** | Deduplicated customers across the historical operational period. |
| **Total Orders** | **96,478** | Valid transactions delivered or processed via the marketplace platform. |
| **Total Revenue** | **R$ 15.42M** | Gross merchandise value including item costs and freight charges. |
| **Average Order Value** | **R$ 159.83** | Platform-wide average ticket per distinct order. |

---

## Data Extraction & Transformation


### <img width="25" height="25" alt="postgresql" src="https://github.com/user-attachments/assets/2fa38274-43fe-453e-bc8b-68914e990da7" /> **1. Core SQL Architecture**

```sql
CREATE OR REPLACE VIEW public.vw_cohort_analysis AS
WITH customer_first_purchase AS (
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp))::DATE AS cohort_month
    FROM public.orders o
    JOIN public.customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_orders AS (
    SELECT 
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month,
        SUM(oi.price) AS total_items_value,
        SUM(oi.freight_value) AS total_freight_value,
        SUM(oi.price + oi.freight_value) AS total_order_value
    FROM public.orders o
    JOIN public.customers c ON o.customer_id = c.customer_id
    JOIN public.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, c.customer_unique_id, o.order_purchase_timestamp
)
SELECT 
    co.order_id,
    co.customer_unique_id,
    co.order_purchase_timestamp,
    cfp.first_purchase_date,
    cfp.cohort_month,
    co.order_month,
    ((EXTRACT(YEAR FROM co.order_month) - EXTRACT(YEAR FROM cfp.cohort_month)) * 12 +
     (EXTRACT(MONTH FROM co.order_month) - EXTRACT(MONTH FROM cfp.cohort_month)))::INT AS cohort_index,
    co.total_items_value,
    co.total_freight_value,
    co.total_order_value
FROM customer_orders co
JOIN customer_first_purchase cfp ON co.customer_unique_id = cfp.customer_unique_id
```

---

### <img width="25" height="25" alt="powerbi" src="https://github.com/user-attachments/assets/09bb7cf9-7119-485d-81e5-82b95d0c34a4" /> **2. DAX Modeling & Measures**

**1. Retention Rate (%)**
```
Cohort Initial Size = 
CALCULATE(
    [Total Unique Customers],
    FactCohort[cohort_index] = 0,
    ALL(FactCohort[cohort_index])
)

Retention Rate % = 
DIVIDE([Total Unique Customers], [Cohort Initial Size], 0)
```



**2. Cumulative Lifetime Value (LTV)**
```
Cumulative LTV = 
VAR CurrentIndex = MAX(FactCohort[cohort_index])
VAR CumulativeRevenue = 
    CALCULATE(
        [Total Revenue],
        FactCohort[cohort_index] <= CurrentIndex,
        ALL(FactCohort[cohort_index])
    )
RETURN
    DIVIDE(CumulativeRevenue, [Cohort Initial Size], 0)
```

**3. Month-over-Month Growth (MoM %)**
```
Revenue PM = 
CALCULATE(
    [Total Revenue],
    PREVIOUSMONTH(dCalendar[Date])
)

Revenue MoM % = 
DIVIDE(
    [Total Revenue] - [Revenue PM],
    [Revenue PM],
    0
)
```

---

## <img width="25" height="25" alt="data-eyes" src="https://github.com/user-attachments/assets/3813c761-9e14-4254-8328-af7460aefb96" /> Dashboard Layout & Visualization

* **Global Slicers:** Year and Month
* **Executive KPI Cards:** Total Unique Customers, Total Orders, Total Revenue, and Average Ticket
* **Retention Matrix:** Cohort heatmap
* **Cumulative LTV Curve:** Maturation trendline by monthly index
* **Financial Performance:** Monthly Revenue & MoM Growth %

<img width="1475" height="140" alt="gif dashboard 2" src="https://github.com/user-attachments/assets/5b20c66e-6035-49be-8b9d-adda261bad7a" />
  
  

## 💡 Strategic Insights & Conclusions

* **Severe Retention Decay:** Month 1 retention drops sharply to **0.35% – 0.72%** and stabilizes below **0.15%** by Month 6, confirming a one-off durable goods marketplace rather than a recurring habit loop.
  
* **Acquisition-Dependent Unit Economics:** Cumulative LTV expands only **+1.76%** over 12 months (from **R$ 162.16** to **R$ 165.02**), meaning CAC payback must occur entirely on the initial transaction to avoid gross margin compression.
  
* **Top-of-Funnel Scaling:** Operational run-rate expanded from **~R$ 0.12M (Jan 2017)** to **~R$ 1.0M – R$ 1.15M/month** in 2018, fueled exclusively by new customer acquisition rather than recurring account monetization.
  
* **Strategic Growth Levers:** Without native repeat triggers, scaling unit economics requires expanding consumable product categories, automated lifecycle re-engagement, and regional seller onboarding to reduce freight friction.
