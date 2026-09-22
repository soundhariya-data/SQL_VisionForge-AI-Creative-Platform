#What information would help us understand meaningful product usage?
#1.Find users whose first activity happened within 7 days of signup.
SELECT
    count(u.user_id),
    u.signup_date,
    MIN(a.activity_date) AS first_activity_date,
    DATEDIFF(MIN(a.activity_date), u.signup_date) AS days_to_activity
FROM users u
JOIN activity a
    ON u.user_id = a.user_id
GROUP BY  u.signup_date
HAVING days_to_activity BETWEEN 0 AND 7;

#This query measures user activation speed — how quickly new users start using the product after signing up.
#If many users activate within 7 days → onboarding may be working well.
#If many users take longer → the business can investigate onboarding, product usability, or user education.

#2.Which users are active, but barely using the platform?(revenue/churn risk)
select u.user_id,account_status,coalesce(sum(content_Created),0) total_content
from users u left join activity a
on u.user_id=a.user_id
where account_status="active"
group by u.user_id,account_status
having coalesce(sum(content_created),0)<10;
#This query gives active but low-engagement users — a good target for onboarding nudges, tutorials, or engagement campaigns.


#3.Paying users who are actually using the product
SELECT
  u.user_id,
  u.signup_date
FROM users u
WHERE EXISTS (
  SELECT 1
  FROM billing_transactions b
  WHERE b.user_id = u.user_id
)
AND EXISTS (
  SELECT 1
  FROM activity a
  WHERE a.user_id = u.user_id
);
#This is our “real users” set: they pay and also use the product.
#using JOINs
SELECT
  u.user_id,
  u.signup_date,
  SUM(b.amount_billed) AS total_billed,
  COUNT(a.activity_id) AS activity_count
FROM users u
JOIN billing_transactions b
  ON b.user_id = u.user_id
LEFT JOIN activity a
  ON a.user_id = u.user_id
GROUP BY u.user_id, u.signup_date
HAVING SUM(b.amount_billed) > 0
   AND COUNT(a.activity_id) > 0;



#Which user or customer patterns are worth investigating?
#4.users whose total billing > average total billing per user
WITH user_totals AS (
  SELECT
    user_id,
    SUM(amount_billed) AS total_billed
  FROM billing_transactions
  GROUP BY user_id
),
platform_avg AS (
  SELECT
    AVG(total_billed) AS avg_billed_per_user
  FROM user_totals
)
SELECT
  ut.user_id,
  ut.total_billed,
  pa.avg_billed_per_user
FROM user_totals ut
CROSS JOIN platform_avg pa
WHERE ut.total_billed > pa.avg_billed_per_user
ORDER BY ut.total_billed DESC;
#This query identifies high-value / high-spend users relative to the rest of the platform.
#Label these users as “Above-average spenders” or “High-value”.
#This query finds users whose lifetime billing is above the platform average, which is a standard way to identify high-value customers for segmentation, retention campaigns, and upsell strategies

#5#Which customers generate high revenue but low usage?
#Define high revenue/low usage
#AVG OF REVENUE AND AVG OF USAGE

SELECT
  b.user_id,
  SUM(b.amount_billed) AS total_revenue,
  SUM(a.Content_created) AS total_usage
FROM billing_transactions b
JOIN activity a
  ON a.user_id = b.user_id
GROUP BY b.user_id
HAVING SUM(b.amount_billed) > 100
   AND SUM(a.Content_created) <14
ORDER BY total_revenue DESC;


#CHANGES OVER TIME

#6.#Monthly Revenue Trend

With billed as
(select date_format(billing_date,'%m-%Y') billing_month,sum(amount_billed) current_revenue
from billing_transactions
group by date_format(billing_date,'%m-%Y'))
select billing_month,current_revenue,lag(current_revenue)over(order by billing_month) previous_revenue,current_revenue-lag(current_revenue)over(order by  billing_month) revenue_diff
from billed;
#This is the most direct way to answer "is revenue growing or shrinking month over month" — rather than 
#just looking at one month in isolation, we see next to the previous month and the actual change.
# A negative revenue_change for two or three consecutive months is an early warning sign worth flagging to 
 #leadership, even if total revenue still looks good in absolute terms for that single month.
 
 
 #7.For each user, compare their monthly content creation with their previous recorded month.
 
 WITH cte AS (
  SELECT
    user_id,
    DATE_FORMAT(activity_date, '%Y-%m') AS activity_month,  -- sortable month
    COALESCE(SUM(content_created), 0)   AS content_monthly
  FROM activity
  GROUP BY
    user_id,
    DATE_FORMAT(activity_date, '%Y-%m')
)
SELECT
  user_id,
  activity_month,
  content_monthly,
  LAG(content_monthly) OVER (
    PARTITION BY user_id
    ORDER BY activity_month
  ) AS previous_month_content,
  content_monthly - LAG(content_monthly) OVER (
    PARTITION BY user_id
    ORDER BY activity_month
  ) AS diff
FROM cte
ORDER BY
  user_id,
  activity_month;
 #Detect engagement trends per user
#diff > 0 → user is creating more content than last month (increasing engagement).
#diff < 0 → user is creating less content (possible drop in interest or churn risk).
#Over time, we can spot users who are ramping up vs slowing down.
#Identify at-risk or churning creators.#Users with several consecutive negative diff values may be disengaging.
#Customer success can proactively reach out: “We noticed you’re posting less – need help?”
#This is a classic early-warning signal for churn in content platforms


#8.Calculate total revenue and number of customers for each plan.
select sum(amount_billed) Total_Revenue,b.plan_id,count(u.user_id) No_of_users
from billing_transactions b join users u 
on u.user_id=b.user_id
group by plan_id
order by No_of_users;

#9.Divide customers into four groups based on their total revenue contribution.
WITH customer_revenue AS (
  SELECT
    b.user_id AS customer_id,
    SUM(b.amount_billed) AS total_revenue
  FROM billing_transactions b
  GROUP BY b.user_id
)
SELECT
  customer_id,
  total_revenue,
  NTILE(4) OVER (
    ORDER BY total_revenue DESC
  ) AS revenue_quartile
FROM customer_revenue
ORDER BY revenue_quartile, total_revenue DESC;
#This segments customers into four tiers by revenue contribution, which is used for:
#Targeted marketing (different offers per quartile).

#10)Customer/Revenue usage segmentation
SELECT
    u.user_id,
    u.account_status,
    COALESCE(SUM(b.amount_billed), 0) AS total_revenue,
    COALESCE(SUM(a.content_created), 0) AS total_content,
    CASE
        WHEN COALESCE(SUM(b.amount_billed), 0) >= 200
             AND COALESCE(SUM(a.content_created), 0) < 5
            THEN 'High Revenue - Low Usage'

        WHEN COALESCE(SUM(b.amount_billed), 0) < 100
             AND COALESCE(SUM(a.content_created), 0) < 5
            THEN 'Low Revenue - Low Usage'

        WHEN COALESCE(SUM(b.amount_billed), 0) >= 100
             AND COALESCE(SUM(a.content_created), 0) >= 10
            THEN 'High Revenue - High Usage'

        ELSE 'Low Revenue - High Usage'
    END AS customer_segment
FROM users u
LEFT JOIN billing_transactions b
    ON u.user_id = b.user_id
LEFT JOIN activity a
    ON u.user_id = a.user_id
WHERE u.account_status = 'active'
GROUP BY
    u.user_id,
    u.account_status;
