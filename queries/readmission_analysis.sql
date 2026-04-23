-- Hospital Patient Readmission Analysis
-- Dataset: Diabetes 130-US Hospitals (1999-2008)
-- Tool: SQLiteStudio
-- Author: Ben Munson



-- QUERY 1: Overall Readmission Rate Breakdown
-- Purpose: Understand the distribution of readmission outcomes
--          across the full patient population

SELECT 
    readmitted,
    COUNT(*) AS patient_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM diabetes_readmission
GROUP BY readmitted
ORDER BY patient_count DESC;



-- QUERY 2: Readmission Rate by Age Group
-- Purpose: Identify which age groups carry the highest
--          30-day readmission risk

SELECT 
    age,
    COUNT(*) AS total_patients,
    SUM(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) AS readmitted_30days,
    ROUND(SUM(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS readmission_rate_pct
FROM diabetes_readmission
GROUP BY age
ORDER BY age;



-- QUERY 3: Impact of Medication Count on Readmission Rate
-- Purpose: Determine whether patients on more medications
--          have higher readmission rates
-- Note: Medication counts with fewer than 50 patients excluded
--       to ensure statistical reliability

SELECT 
    num_medications,
    COUNT(*) AS total_patients,
    ROUND(SUM(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS readmission_rate_pct
FROM diabetes_readmission
GROUP BY num_medications
HAVING COUNT(*) >= 50
ORDER BY CAST(num_medications AS INTEGER);



-- QUERY 4: Top 15 Primary Diagnoses by 30-Day Readmission Rate
-- Purpose: Surface which clinical diagnoses are most strongly
--          associated with early readmission
-- Note: Only diagnoses with 100 or more patients included
--       to ensure statistical significance

SELECT 
    diag_1 AS primary_diagnosis,
    COUNT(*) AS total_patients,
    ROUND(SUM(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS readmission_rate_pct
FROM diabetes_readmission
GROUP BY diag_1
HAVING COUNT(*) >= 100
ORDER BY readmission_rate_pct DESC
LIMIT 15;



-- QUERY 5: High Risk Patient Profile
-- Purpose: Identify combinations of age, hospital stay length,
--          and medication count that produce the highest
--          readmission rates among complex patients

SELECT 
    age,
    num_medications,
    time_in_hospital,
    number_diagnoses,
    COUNT(*) AS total_patients,
    ROUND(SUM(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS readmission_rate_pct
FROM diabetes_readmission
WHERE time_in_hospital >= 7
  AND num_medications >= 15
GROUP BY age, num_medications, time_in_hospital, number_diagnoses
HAVING COUNT(*) > 10
ORDER BY readmission_rate_pct DESC
LIMIT 20;



-- Query 6: Age Groups Above Overall 30-Day Readmission Average
-- Purpose: Identify which age groups exceed the overall readmission
--          benchmark and quantify how far above average each sits


WITH high_risk AS (
    SELECT age,
           ROUND(SUM(CASE
                         WHEN readmitted = '<30' THEN 1
                         ELSE 0
                     END) * 100.0 / COUNT( * ), 2) AS readmission_rate_pct
     FROM diabetes_readmission
     GROUP BY age
),
overall_rate AS (
    SELECT ROUND(SUM(CASE
                         WHEN readmitted = '<30' THEN 1
                         ELSE 0
                     END) * 100.0 / COUNT( * ), 2) AS overall_avg
      FROM diabetes_readmission
)
SELECT age,
       readmission_rate_pct,
       ROUND(readmission_rate_pct - overall_avg, 2) AS pct_above_avg
  FROM high_risk
       CROSS JOIN
       overall_rate
 WHERE readmission_rate_pct > overall_avg;



-- Query 7: Diagnoses Ranked by Readmission Risk (CTE + RANK)
-- Purpose: Extends Query 4 using a CTE and RANK() window function
--          to formally rank diagnoses by 30-day readmission rate.
--          Demonstrates ranked filtering using a subquery wrapper
-- Note: Tied readmission rates receive the same rank (RANK behavior).
--       DENSE_RANK() would eliminate gaps between tied values.



SELECT *
  FROM (
       WITH readmission_by_diagnosis AS (
               SELECT diag_1 AS primary_diagnosis,
                      COUNT( * ) AS total_patients,
                      ROUND(SUM(CASE
                                    WHEN readmitted = '<30' THEN 1
                                    ELSE 0
                                END) * 100.0 / COUNT( * ), 2) AS readmission_rate_pct
                 FROM diabetes_readmission
                GROUP BY diag_1
               HAVING COUNT( * ) >= 100
           )
           SELECT RANK() OVER (ORDER BY readmission_rate_pct DESC) AS readmission_rank,
                  primary_diagnosis,
                  total_patients,
                  readmission_rate_pct
             FROM readmission_by_diagnosis
            ORDER BY readmission_rate_pct DESC
       )
 WHERE readmission_rank <= 15;
