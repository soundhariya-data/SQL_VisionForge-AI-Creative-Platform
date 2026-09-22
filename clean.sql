select * from activity;
select * from plans;
select * from users;

#------------------------BASIC ANALYSIS------------------------------------------------#
1)What are the total number of users and users who engage with the product?
SELECT 
    COUNT(DISTINCT u.user_id) AS total_users,
    COUNT(DISTINCT a.user_id) AS users_with_activity
FROM users u
LEFT JOIN activity a ON u.user_id = a.user_id;
 #The single most basic activation check — of everyone who signed up, how many ever actually used the product at all.

What is the total content created, and total revenue, across the platform?
SELECT
  SUM(a.Content_created) AS total_content_created,
  SUM(b.amount_billed)   AS total_revenue
FROM activity a
JOIN billing_transactions b
  ON b.user_id = a.user_id;
  
#Inference:Overall platform output and overall revenue, before any segmentation.

#3How many users are on each plan?
select count(user_id),u.plan_id,plan_name
from users u left join plans p
on u.plan_id=p.plan_id
group by plan_id;

#4Usage-Based Customer Segmentation
select u.user_id,sum(content_Created) TOTAL_CONTENT,CASE WHEN sum(content_Created)>10 then "HIGH USAGE"
															         WHEN sum(content_Created)<10 THEN "LOW USAGE"
                                                                     ELSE "MODERATE USAGE" END AS "USAGE"
from users u join activity a
on u.user_id=a.user_id
join plans p
on p.plan_id=u.plan_id
group by u.user_id;
#To understand how actively different customers are using the product and target engagement efforts accordingly
#High Usage → understand what keeps these customers engaged and encourage continued usage.
#Medium Usage → identify opportunities to increase engagement.
#Low Usage → investigate whether they need onboarding, training, support, or product improvements.

