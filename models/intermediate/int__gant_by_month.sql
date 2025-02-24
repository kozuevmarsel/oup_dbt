{{
  config(
    materialized = 'table',
    indexes=[
      {'columns': ['code'], 'type': 'hash'}]
    )
}}



WITH RECURSIVE cte_dates AS (
    SELECT
    gant_index,
    code,
    start_date,
    end_date,
    start_year,
    start_month,
    project_type,
    "object" 
    
  FROM {{ ref('int__gant_start_transform') }}
  
  UNION ALL
  
  SELECT
  	gant_index,
    code,
    start_date + INTERVAL '1 MONTH',
    end_date,
    EXTRACT(YEAR FROM start_date + INTERVAL '1 MONTH'),
    EXTRACT(MONTH FROM start_date + INTERVAL '1 MONTH'),
    project_type,
    "object"
   
  FROM cte_dates 
  WHERE date_trunc('month', start_date + INTERVAL '1 MONTH') <= date_trunc('month', end_date)
), 



tmp_dates AS (SELECT
	  gant_index,
    code,
    start_date,
    end_date,
    start_year,
    start_month,
    project_type,
    "object",
    
    CASE

		WHEN start_date = MAX(start_date) OVER (PARTITION BY code, gant_index) AND date_trunc('month', start_date) = date_trunc('month', end_date)  
			THEN date_part('day', end_date)
    	WHEN start_date = MIN(start_date) OVER (PARTITION BY code, gant_index) THEN
    		CASE 
    			WHEN date_part('day', (date_trunc('month', start_date) + interval '1 month' - interval '1 day') - date_trunc('day', start_date)) = 0
    			THEN date_part('day', start_date)
    			ELSE date_part('day', (date_trunc('month', start_date) + interval '1 month' - interval '1 day') - date_trunc('day', start_date))
    		END
    	ELSE date_part('day', (date_trunc('month', start_date) + INTERVAL '1 MONTH'  - interval '1 day'))
    END AS num_days -- использовать только для расчета весов
    
FROM cte_dates),


 tmp_2 AS (SELECT
 	  gant_index,
    code,
    start_date,
    end_date,
    project_type,
    "object",
    start_year,
    start_month,
    num_days,
    num_days/sum(num_days) OVER (PARTITION BY code) AS weight

FROM tmp_dates)

SELECT
	t.gant_index,
	t.code,
  t.start_year,
  t.start_month,
  'план' as smr_type,
  --доп поля

  r."object",
  r."Name", 
  weight * r."c_pln_SMRSsI" as smr_ss,
  weight * r."c_pln_SMRSpI" as smr_sp,
  r."Ispol",
  r."IspolUch", 
  r."Real",
  r."SNT_Knstr",
  r."SNT_KnstrE",
  r."SNT_Obj"

FROM tmp_2 t
	
JOIN {{source('spider', 'raw_spider__gandoper')}} r 

{# to do: уникальный индекс в таблице исходных данных #}
ON t.gant_index = r."index" AND t.code = r."Code" AND t.project_type = r.project_type
