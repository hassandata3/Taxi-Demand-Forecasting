# Creating tables and setting the data types

-- allow LOAD DATA to read files from disk
SET GLOBAL local_infile = 1;

-- raw trip records, loaded exactly as they come from the app
CREATE TABLE raw_trips (
trip_id				VARCHAR(20),
pickup_datetime 	DATETIME,
dropoff_datetime 	DATETIME NULL,
pickup_zone			VARCHAR(50),
dropoff_zone		VARCHAR(50),
trip_status			VARCHAR(50),
distance_km			DECIMAL(6,2) NULL,
duration_min		DECIMAL(6,2) NULL,
fare_iqd			INT NULL,
payment_type		VARCHAR(20),
passenger_count		INT NULL,
vehicle_type		VARCHAR(20),
driver_id			VARCHAR(20) NULL,
driver_rating		DECIMAL(2,1) NULL
);

-- zone lookup: name, side of the city, coordinates, type
CREATE TABLE zones (
    zone_id      INT PRIMARY KEY,
    zone_name    VARCHAR(50),
    city_side    VARCHAR(20),
    latitude     DECIMAL(6,4),
    longitude    DECIMAL(6,4),
    zone_type    VARCHAR(20)
);

-- one weather reading per hour
CREATE TABLE weather_hourly (
    hour_ts        DATETIME PRIMARY KEY,
    temp_c         DECIMAL(4,1),
    rain_mm        DECIMAL(4,1),
    is_dust_storm  TINYINT
);

-- one row per day: weekend flag, Ramadan, Eid, holidays, etc.
CREATE TABLE calendar_daily (
    cal_date             DATE PRIMARY KEY,
    day_name             VARCHAR(10),
    is_weekend_iraq      TINYINT,
    is_ramadan           TINYINT,
    is_eid               TINYINT,
    is_public_holiday    TINYINT,
    is_religious_event   TINYINT,
    is_university_break  TINYINT,
    event_name           VARCHAR(30)
);

-- quick look at what status values actually exist before cleaning
SELECT DISTINCT trip_status
FROM raw_trips;

#================================================================

# Creating tables and setting the data types

-- load the raw trips CSV; messy numeric/date fields go into variables first
-- so NULLIF can turn empty text into real NULLs
LOAD DATA LOCAL INFILE 'C:/Data Analysis/DF delivery/baghdad_taxi_trips_raw.csv'
INTO TABLE raw_trips
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(trip_id, pickup_datetime, @dropoff, pickup_zone, dropoff_zone, trip_status,
 @distance, @duration, @fare, payment_type, @passengers, vehicle_type,
 @driver, @rating)
SET
    -- NULLIF turns empty text "" into a real NULL so numeric columns don't error
    dropoff_datetime = NULLIF(@dropoff, ''),
    distance_km       = NULLIF(@distance, ''),
    duration_min      = NULLIF(@duration, ''),
    fare_iqd          = NULLIF(@fare, ''),
    passenger_count   = NULLIF(@passengers, ''),
    driver_id         = NULLIF(@driver, ''),
    driver_rating     = NULLIF(@rating, '');

#================================================================

-- load the zone lookup table
LOAD DATA LOCAL INFILE 'C:/Data Analysis/DF delivery/baghdad_zones.csv'
INTO TABLE zones
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- load hourly weather
LOAD DATA LOCAL INFILE 'C:/Data Analysis/DF delivery/baghdad_weather_hourly.csv'
INTO TABLE weather_hourly
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- load the daily calendar
LOAD DATA LOCAL INFILE 'C:/Data Analysis/DF delivery/baghdad_calendar.csv'
INTO TABLE calendar_daily
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- sanity check: row counts should roughly match the CSVs
SELECT 'raw_trips' AS Tabl , COUNT(*) AS rows_loaded FROM raw_trips
UNION ALL SELECT 'zones' , COUNT(*) FROM zones
UNION ALL SELECT 'weather_hourly' , COUNT(*) FROM weather_hourly
UNION ALL SELECT 'calendar_daily' , COUNT(*) FROM calendar_daily;

#================================================================

-- lookup table that maps every messy zone spelling to one clean name
CREATE TABLE zone_name_map (
messy_names VARCHAR (50) PRIMARY KEY,
clean_names VARCHAR (50)
);
INSERT INTO zone_name_map (messy_names,clean_names) VALUES
('karada','Karada'),('karrada','Karada'),('alkarada','Karada'),('karadah','Karada'),
('mansour','Al-Mansour'),('almansour','Al-Mansour'),('mansur','Al-Mansour'),
('zayouna','Zayouna'),('zayuna','Zayouna'),('zayona','Zayouna'),('alzayouna','Zayouna'),
('jadriyah','Jadriyah'),('jadiriyah','Jadriyah'),('aljadriyah','Jadriyah'),('jadriya','Jadriyah'),
('yarmouk','Al-Yarmouk'),('alyarmouk','Al-Yarmouk'),('yarmuk','Al-Yarmouk'),('alyarmuk','Al-Yarmouk'),
('adhamiyah','Al-Adhamiyah'),('aladhamiyah','Al-Adhamiyah'),('adhamiya','Al-Adhamiyah'),('aladhamiya','Al-Adhamiyah'),
('jamila','Jamila'),('aljamila','Jamila'),('jameela','Jamila'),('aljameela','Jamila'), ('Al-Jamila','Jamila'),
('maghreb','Al-Maghreb'),('almaghreb','Al-Maghreb'),('almaghrib','Al-Maghreb');

#================================================================

-- clean the raw trips: fix zone names/status text, drop duplicates and bad rows
CREATE TABLE trips_clean AS
SELECT  
	trip_id		        ,
	pickup_datetime 	,
	dropoff_datetime 	,
	pickup_zone			,
	dropoff_zone		,
	trip_status			,
	distance_km			,
	duration_min		,
	fare_iqd			,
	payment_type		,
	passenger_count		,
	vehicle_type		,
	driver_id			,
	driver_rating	
FROM (
	   SELECT r.trip_id , r.pickup_datetime , r.dropoff_datetime,
       COALESCE(zm_p.clean_names, r.pickup_zone) AS pickup_zone,
       COALESCE(zm_d.clean_names, r.dropoff_zone) AS dropoff_zone,
       CASE WHEN LOWER(TRIM(r.trip_status)) LIKE 'complet%' THEN 'completed'
			WHEN LOWER(TRIM(r.trip_status)) LIKE '%driver%'
				 AND LOWER(TRIM(r.trip_status)) LIKE '%cancel%' THEN 'cancelled_by_driver'
            WHEN LOWER(TRIM(r.trip_status)) LIKE '%rider%'
                 AND LOWER(TRIM(r.trip_status)) LIKE '%cancel%'    THEN 'cancelled_by_rider'
            WHEN LOWER(TRIM(r.trip_status)) LIKE '%no%driver%'     THEN 'no_driver_found'
            ELSE LOWER(TRIM(r.trip_status))       
			END AS trip_status,
		CASE WHEN r.distance_km BETWEEN 0.1 AND 100  THEN r.distance_km END AS distance_km,
        CASE WHEN r.duration_min BETWEEN 1 AND 180  THEN r.duration_min END AS duration_min,
        CASE WHEN r.fare_iqd > 0                    THEN r.fare_iqd     END AS fare_iqd, r.payment_type,
        CASE WHEN r.passenger_count BETWEEN 1 AND 6 THEN r.passenger_count END AS passenger_count, r.vehicle_type, r.driver_id, r.driver_rating,
        ROW_NUMBER() OVER(PARTITION BY r.trip_id ORDER BY r.pickup_datetime) AS rn
FROM raw_trips r
	LEFT JOIN zone_name_map zm_p
	ON zm_p.messy_names = LOWER(REGEXP_REPLACE(TRIM(r.pickup_zone),'[^A-Za-z]', ''))
	LEFT JOIN zone_name_map zm_d
	ON zm_d.messy_names = LOWER(REGEXP_REPLACE(TRIM(r.dropoff_zone),'[^A-Za-z]', ''))

WHERE 
	r.pickup_zone IS NOT NULL AND TRIM(r.pickup_zone) <> ''
	AND r.pickup_datetime BETWEEN '2025-01-01' AND '2026-06-30 23:59:59'
	AND r.dropoff_datetime IS NULL OR r.dropoff_datetime >= r.pickup_datetime 
    AND r.dropoff_datetime IS NULL
		OR TIMESTAMPDIFF(HOUR , pickup_datetime , dropoff_datetime) <= 10
)t
WHERE t.rn = 1;

-- eyeball the cleaned data
SELECT * FROM trips_clean;

#================================================================

-- cancelled / no-driver trips shouldn't carry a fare or distance
UPDATE trips_clean
SET fare_iqd = NULL , distance_km = NULL , duration_min = NULL 
WHERE trip_status <> 'completed';

#================================================================

-- raise the recursion limit before building the hour spine below
SET SESSION cte_max_recursion_depth = 20000;

#================================================================

-- every hour in the study period, one row each
CREATE TABLE hour_spine AS

WITH RECURSIVE hours AS (
	SELECT TIMESTAMP('2025-01-01 00:00:00') AS hour_ts
	UNION ALL
	SELECT hour_ts + INTERVAL 1 HOUR
	FROM hours
	WHERE hour_ts < '2026-06-30 23:00:00')
SELECT hour_ts FROM hours;

#================================================================

-- cross every hour with every zone so no zone-hour combination is ever missing
CREATE TABLE zone_hour_spine AS
SELECT h.hour_ts , z.zone_name
FROM hour_spine h
CROSS JOIN zones z;

#================================================================

-- speeds up the join in the next step
CREATE INDEX idx_spine_hour_zone ON zone_hour_spine (hour_ts, zone_name);

#================================================================

-- count requests/completed/no-driver/cancelled per zone per hour
CREATE TABLE trips_hourly_all AS
SELECT
    DATE_ADD(DATE(pickup_datetime), INTERVAL HOUR(pickup_datetime) HOUR) AS hour_ts,
    pickup_zone AS zone_name,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN trip_status = 'completed' THEN 1 ELSE 0 END) AS demand,
    SUM(CASE WHEN trip_status = 'no_driver_found' THEN 1 ELSE 0 END) AS no_driver_found,
    SUM(CASE WHEN trip_status IN ('cancelled_by_rider','cancelled_by_driver')
             THEN 1 ELSE 0 END) AS cancelled
FROM trips_clean
GROUP BY hour_ts, pickup_zone;

#================================================================

-- speeds up the join in the next step
CREATE INDEX idx_hourly_hour_zone ON trips_hourly_all (hour_ts , zone_name);

#================================================================

-- left join the real counts onto the spine; missing hours become zero, not absent
CREATE TABLE trips_hourly_final AS
SELECT
    s.hour_ts,
    s.zone_name,
    COALESCE(a.total_requests, 0) AS total_requests,
    COALESCE(a.demand, 0)         AS demand,
    COALESCE(a.no_driver_found, 0) AS no_driver_found,
    COALESCE(a.cancelled, 0)      AS cancelled
FROM zone_hour_spine s
LEFT JOIN trips_hourly_all a
       ON a.hour_ts = s.hour_ts AND a.zone_name = s.zone_name;

-- should equal zones x hours exactly
SELECT COUNT(*) AS total_rows FROM trips_hourly_final;

#================================================================

-- final table: demand + weather + calendar, one row per zone per hour
CREATE TABLE trips_hourly_analytical AS
SELECT
    f.hour_ts,
    f.zone_name,
    z.zone_type,
    z.city_side,
    z.latitude,
    z.longitude,
    f.total_requests,
    f.demand,
    f.no_driver_found,
    f.cancelled,
    w.temp_c,
    w.rain_mm,
    w.is_dust_storm,
    c.day_name,
    c.is_weekend_iraq,
    c.is_ramadan,
    c.is_eid,
    c.is_public_holiday,
    c.is_religious_event,
    c.is_university_break,
    c.event_name
FROM trips_hourly_final f
JOIN zones z ON z.zone_name = f.zone_name
LEFT JOIN weather_hourly w ON w.hour_ts = f.hour_ts
LEFT JOIN calendar_daily c ON c.cal_date = DATE(f.hour_ts)
ORDER BY f.zone_name, f.hour_ts;

-- confirm every row got a weather and calendar match
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN temp_c IS NULL THEN 1 ELSE 0 END) AS missing_weather,
    SUM(CASE WHEN day_name IS NULL THEN 1 ELSE 0 END) AS missing_calendar
FROM trips_hourly_analytical;

-- final output, ready to export for Python / Power BI
SELECT * FROM trips_hourly_analytical ;

-- spot check on one zone
SELECT zone_name , SUM(total_requests)
FROM trips_hourly_final
WHERE zone_name = 'Jamila'
GROUP BY zone_name;
