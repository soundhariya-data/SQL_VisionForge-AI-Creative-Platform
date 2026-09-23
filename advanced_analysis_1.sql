/* ============================================================
   SECTION 1: WHAT INFORMATION HELPS US UNDERSTAND
   MEANINGFUL PRODUCT USAGE?
   ============================================================ */

-- Q1. Find users whose first activity happened within 7 days of signup
SELECT
    u.user_id                              
    u.signup_date,
    MIN(a.activity_date)                               AS first_activity_date,
    DATEDIFF(MIN(a.activity_date), u.signup_date)      AS days_to_activity
FROM users u
JOIN activity a
    ON u.user_id = a.user_id
GROUP BY u.signup_date,u.user_id
HAVING days_to_activity BETWEEN 0 AND 7;

-- This query measures user activation speed — how quickly new users
-- start using the product after signing up.
--   • Many users activating within 7 days -> onboarding is working well
--   • Many users taking longer            -> investigate onboarding,
--     usability, or user education


-- Q2. Which users are active, but barely using the platform?
--     (revenue/churn risk)
SELECT
    u.user_id,
    u.account_status,
    COALESCE(SUM(a.content_created), 0)                AS total_content
FROM users u
LEFT JOIN activity a
    ON u.user_id = a.user_id
WHERE u.account_status = 'active'
GROUP BY u.user_id, u.account_status
HAVING COALESCE(SUM(a.content_created), 0) < 10;

-- Surfaces active-but-low-engagement users — a good target for
-- onboarding nudges, tutorials, or engagement campaigns.


-- Q3. Paying users who are actually using the product
SELECT
    u.user_id,
    u.signup_date,
    SUM(b.amount_billed)    AS total_billed,
    COUNT(a.activity_id)    AS activity_count
FROM users u
JOIN billing_transactions b
    ON b.user_id = u.user_id
LEFT JOIN activity a
    ON a.user_id = u.user_id
GROUP BY u.user_id, u.signup_date
HAVING SUM(b.amount_billed) > 0
   AND COUNT(a.activity_id) > 0;
-- These are our "real users" set: they pay AND use the product.

/* ============================================================
   SECTION 2: WHICH USER OR CUSTOMER PATTERNS
   ARE WORTH INVESTIGATING?
   ============================================================ */

-- Q4. Users whose total billing exceeds the platform average
WITH user_totals AS (
    SELECT
        user_id,
        SUM(amount_billed)  AS total_billed
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

-- Identifies high-value / high-spend users relative to the rest of
-- the platform ("Above-average spenders"). Standard approach for
-- segmentation, retention campaigns, and upsell targeting.





/* ============================================================
   SECTION 3: WHAT CHANGES OVER TIME COULD REVEAL
   SOMETHING IMPORTANT?
   ============================================================ */

-- Q6. Monthly revenue trend (with prior-month comparison)
WITH billed AS (
    SELECT
        DATE_FORMAT(billing_date, '%m-%Y')             AS billing_month,
        SUM(amount_billed)                             AS current_revenue
    FROM billing_transactions
    GROUP BY DATE_FORMAT(billing_date, '%m-%Y')
)
SELECT
    billing_month,
    current_revenue,
    LAG(current_revenue) OVER (ORDER BY billing_month)     AS previous_revenue,
    current_revenue - LAG(current_revenue) OVER (ORDER BY billing_month)
                                                            AS revenue_diff
FROM billed;

-- Most direct way to answer "is revenue growing or shrinking month
-- over month" — rather than looking at one month in isolation, we see
-- it next to the previous month and the actual change.
-- A negative revenue_diff for 2-3 consecutive months is an early
-- warning worth flagging to leadership, even if the absolute total
-- still looks fine for that single month.


-- Q7. For each user, compare monthly content creation to the
--     previous recorded month
WITH cte AS (
    SELECT
        user_id,
        DATE_FORMAT(activity_date, '%Y-%m')            AS activity_month,
        COALESCE(SUM(content_created), 0)              AS content_monthly
    FROM activity
    GROUP BY user_id, DATE_FORMAT(activity_date, '%Y-%m')
)
SELECT
    user_id,
    activity_month,
    content_monthly,
    LAG(content_monthly) OVER (
        PARTITION BY user_id ORDER BY activity_month
    )                                                   AS previous_month_content,
    content_monthly - LAG(content_monthly) OVER (
        PARTITION BY user_id ORDER BY activity_month
    )                                                   AS diff
FROM cte
ORDER BY user_id, activity_month;

-- Detects engagement trends per user:
--   • diff > 0 -> creating more content than last month (increasing engagement)
--   • diff < 0 -> creating less content (possible drop in interest / churn risk)
-- Over time, spot users ramping up vs. slowing down.
-- Users with several consecutive negative diffs may be disengaging —
-- a classic early-warning signal for churn in content platforms.
-- Customer success can proactively reach out: "We noticed you're
-- posting less — need help?"


-- Q8. Total revenue and number of customers per plan
SELECT
    b.plan_id,
    SUM(b.amount_billed)                               AS total_revenue,
    COUNT(u.user_id)                                   AS no_of_users
FROM billing_transactions b
JOIN users u
    ON u.user_id = b.user_id
GROUP BY b.plan_id
ORDER BY no_of_users;


-- Q9. Divide customers into four groups (quartiles) by total
--     revenue contribution
WITH customer_revenue AS (
    SELECT
        b.user_id                                      AS customer_id,
        SUM(b.amount_billed)                           AS total_revenue
    FROM billing_transactions b
    GROUP BY b.user_id
)
SELECT
    customer_id,
    total_revenue,
    NTILE(4) OVER (ORDER BY total_revenue DESC)        AS revenue_quartile
FROM customer_revenue
ORDER BY revenue_quartile, total_revenue DESC;

-- Segments customers into four tiers by revenue contribution.
-- Used for targeted marketing — different offers per quartile.

-- Q10. Churned customers based on customer_group
SELECT
    customer_group,
    COUNT(*) AS total_customers,
    COUNT(CASE
        WHEN account_status = 'cancelled' THEN 1
    END) AS cancelled_customers,
    COUNT(CASE
        WHEN account_status = 'cancelled' THEN 1
    END) * 100.0 / COUNT(*) AS churn_rate
FROM users
GROUP BY customer_group
ORDER BY churn_rate DESC;

-- Q11. Customer segmentation by revenue and usage
SELECT
    u.user_id,
    u.account_status,
    COALESCE(SUM(b.amount_billed), 0) AS total_revenue,
    COALESCE(SUM(a.content_created), 0) AS total_content,
    CASE
        WHEN COALESCE(SUM(b.amount_billed), 0) >= 216
             AND COALESCE(SUM(a.content_created), 0) < 15
            THEN 'High Revenue - Low Usage'

        WHEN COALESCE(SUM(b.amount_billed), 0) < 216
             AND COALESCE(SUM(a.content_created), 0) < 15
            THEN 'Low Revenue - Low Usage'

        WHEN COALESCE(SUM(b.amount_billed), 0) >= 216
             AND COALESCE(SUM(a.content_created), 0) >= 15
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
