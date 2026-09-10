# Baghdad Taxi Demand Forecasting

Predicts hourly ride demand across 8 Baghdad districts to help a taxi app place drivers ahead of demand, not after it.

## Pipeline

1. **SQL (MySQL)** — clean messy raw trip data (inconsistent zone spellings, duplicate trips, bad timestamps), build a complete zone × hour panel with zero-filled gaps
2. **Python (pandas, XGBoost)** — EDA, feature engineering (lags, rolling averages, calendar features), time-based train/test split, model
3. **Power BI** — interactive Dashboard

## Data

18 months (Jan 2025 – Jun 2026) across Karada, Al-Mansour, Zayouna, Jadriyah, Al-Yarmouk, Al-Adhamiyah, Al-Jamila, and Al-Maghreb. Synthetic, built to reproduce real Baghdad patterns: the Friday–Saturday weekend, Ramadan (including the suhoor spike), Eid, Ashura, dust storms, and a distinct demand shape per district (Al-Jamila's dawn market rush, Jadriyah's university calendar, etc).

## Insights

- **Peak hours** — two daily peaks, 08:00 (11.2 trips/zone) and 18:00 (10.9). Quietest hour is 02:00 (0.9).
- **Zones** — Karada leads at 11.0 trips/hour, more than double the quietest zone, Al-Maghreb (4.8).
- **The Iraqi weekend** — Friday runs 41% below Sunday; Thursday, the last workday evening, is 11% *above* Sunday.
- **Ramadan** — daytime demand drops 42%, the pre-iftar rush climbs 59%, evenings run 89% higher, and a suhoor spike near 02:00–04:00 hits +145% — a pattern with no equivalent the rest of the year.
- **University calendar** — Jadriyah drops 63% during campus breaks; no other zone shows this effect, confirming it's tied to the university, not the season.
- **Weather** — rain lifts demand slightly (7.1 → 7.6) but nearly doubles the unserved-request rate (13.7% → 19.9%) — supply can't keep pace when it rains. Dust storms cut demand outright (7.1 → 6.1).

## Results

| Model | MAE | RMSE | R² |
|---|---|---|---|
| Baseline (same hour last week) | 3.73 | 5.37 | 0.48 |
| XGBoost | 2.63 | 3.83 | 0.73 |

29% lower error than the baseline. The model underpredicts slightly (−0.6 trips/hour on average) because test-period demand grew past what it saw in training — a stated limitation, not a hidden one.

## Files

- `baghdad_taxi_*.csv` — raw dataset: trips, zones, weather, calendar
- `baghdad_taxi_sql_pipeline.sql` — cleaning and aggregation
- `Baghdad_Taxi_Demand_Project.ipynb` — EDA, feature engineering, model (Colab)
- `Baghdad Taxi Demand Dashboard.html` — results dashboard, opens in any browser

## Running it

1. Run the SQL script in MySQL against the four CSVs
2. Export `trips_hourly_analytical` to CSV
3. Upload that CSV into the notebook and run all cells
4. Open the dashboard HTML to view results

## Tools

MySQL · Python (pandas, scikit-learn, XGBoost) · Power BI
