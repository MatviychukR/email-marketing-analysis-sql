---знаходження дати створення акаунту по його першій сесії
WITH account_first_session AS (
  SELECT
  ac.id as account_id,
  min(s.date) as first_session_date,
  sp.country,
  ac.send_interval,
  ac.is_verified as is_verified,
  ac.is_unsubscribed as is_unsubscribed

  FROM `DA.account` as ac
  JOIN `DA.account_session` as acs
  ON ac.id=acs.account_id
  JOIN `DA.session` as s
  ON acs.ga_session_id=s.ga_session_id
  JOIN `DA.session_params` as sp
  ON acs.ga_session_id=sp.ga_session_id

  GROUP BY account_id, sp.country,4,5,6
),



--- обчислення кількість акаунтів
 account_calculation AS (
  SELECT
  first_session_date as date,
  country,
  send_interval,
  is_verified,
  is_unsubscribed,
  count(DISTINCT account_id) as account_cnt,
  0 as sent_msg,
  0 as open_msg,
  0 as visit_msg

  FROM account_first_session
  GROUP BY 1,2,3,4,5),



--- обчислення емейл метрик
  email_metrics AS (
    SELECT
    DATE_ADD(s.date, INTERVAL es.sent_date DAY) as date,
    sp.country as country,
    ac.send_interval as send_interval,
    ac.is_verified as is_verified,
    ac.is_unsubscribed as is_unsubscribed,
    0 as account_cnt,
    count(DISTINCT es.id_message) as sent_msg,
    count(DISTINCT eo.id_message) as open_msg,
    count(DISTINCT ev.id_message) as visit_msg

    FROM `DA.email_sent` as es
    LEFT JOIN `DA.email_open` as eo
    ON es.id_message=eo.id_message
    LEFT JOIN `DA.email_visit` as ev
    ON es.id_message=ev.id_message
    JOIN `DA.account` as ac
    ON es.id_account=ac.id
    JOIN `DA.account_session` as acs
    ON ac.id=acs.account_id
    JOIN `DA.session` as s
    ON acs.ga_session_id=s.ga_session_id
    JOIN `DA.session_params` as sp
    ON acs.ga_session_id=sp.ga_session_id
   
    GROUP BY 1,2,3,4,5),


---об'єднання результатів по акаунтам та емайлам
final AS (
SELECT
  date,
  country,
  send_interval,
  is_verified,
  is_unsubscribed,
  account_cnt,
  sent_msg,
  open_msg,
  visit_msg

FROM account_calculation

UNION ALL

SELECT
  date,
  country,
  send_interval,
  is_verified,
  is_unsubscribed,
  account_cnt,
  sent_msg,
  open_msg,
  visit_msg

FROM email_metrics),


---сумування даних, щоб прибрати нулі, які залишилася після UNION
all_info_from_final AS (
SELECT
    date,
    country,
    send_interval,
    is_verified,
    is_unsubscribed,
    sum(account_cnt) as account_cnt,
    SUM(sent_msg) AS sent_msg,
    SUM(open_msg) AS open_msg,
    SUM(visit_msg) AS visit_msg

FROM final
GROUP BY 1,2,3,4,5),



---обчислення загальної кількості листів та акаунтів по країні
country_totals AS (
SELECT
  country,
  sum(account_cnt)  as total_country_account_cnt,
  sum(sent_msg)  as total_country_sent_cnt

FROM all_info_from_final
GROUP BY country),



---створення рейтингу країн за акаунтами та листами
ranks AS (
SELECT *,
  dense_rank() over( order by total_country_account_cnt DESC) as rank_total_country_account_cnt,
  dense_rank() over( order by  total_country_sent_cnt DESC) as rank_total_country_sent_cnt
FROM country_totals)



--- фінальний запит, який фільтрує рейтинг
SELECT
all_info_from_final.*,
ranks.total_country_account_cnt,
ranks.total_country_sent_cnt,
ranks.rank_total_country_account_cnt,
ranks.rank_total_country_sent_cnt

FROM all_info_from_final
JOIN ranks
ON all_info_from_final.country=ranks.country
WHERE rank_total_country_account_cnt<=10 OR rank_total_country_sent_cnt<=10
