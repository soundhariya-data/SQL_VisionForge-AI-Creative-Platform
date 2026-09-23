/* ============================================================
   PREVIEW QUERIES
   ============================================================ */

SELECT * FROM activity;
SELECT * FROM plans;
SELECT * FROM users;
SELECT * from billing_transactions;


/* ============================================================
   BASIC ANALYSIS
   ============================================================ */

-- Q1. Total users vs. users who have ever created content
SELECT
    COUNT(DISTINCT u.user_id)                          AS total_users,
    COUNT(DISTINCT a.user_id)                          AS users_with_activity
FROM users u
LEFT JOIN activity a
    ON u.user_id = a.user_id;

-- The single most basic activation check — of everyone who signed up,
-- how many ever actually used the product at all.


-- Q2. Total content created, and total revenue, across the platform

SELECT
    (SELECT SUM(content_created) FROM activity)            AS total_content_created,
    (SELECT SUM(amount_billed) FROM billing_transactions)  AS total_revenue;
    
-- Inference: overall platform output and overall revenue, before any  segmentation.


-- Q3. How many users are on each plan?
SELECT
    p.plan_name,
    u.plan_id,
    COUNT(u.user_id)                                   AS no_of_users
FROM users u
LEFT JOIN plans p
    ON u.plan_id = p.plan_id
GROUP BY u.plan_id, p.plan_name;


-- Q4. Usage-based customer segmentation
SELECT
    u.user_id,
    SUM(a.content_created)  AS total_content,
   FROM users u
JOIN activity a
    ON u.user_id = a.user_id
GROUP BY u.user_id;

-- Purpose: understand how actively different customers use the
-- product, to target engagement efforts accordingly.
--   • High usage     -> understand what keeps them engaged, encourage continued usage
--   • Moderate usage  -> identify opportunities to increase engagement
--   • Low usage      -> investigate onboarding, training, support, or product gaps
