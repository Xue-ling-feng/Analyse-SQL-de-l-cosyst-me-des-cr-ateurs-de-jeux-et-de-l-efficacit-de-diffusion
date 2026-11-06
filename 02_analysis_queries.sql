-- ============================================================
-- Script d'analyse principal : analyse de l'écosystème des créateurs de jeux et de l'efficacité des diffusions de contenu
-- Compatibilité : MySQL 8.0+ ; pour PostgreSQL, remplacer DATE_FORMAT par TO_CHAR
-- Chaque bloc est marqué par "-- @query qN", exécutable séparément ; les résultats correspondent un à un aux fichiers du dossier 03_query_outputs/
-- ============================================================



-- @query q1
-- Scénario 1 : statistiques des indicateurs de valeur clé des créateurs
-- Consigne : pré-agréger séparément le nombre de contenus et le nombre d'inscriptions dans des CTE, pour éviter le double comptage des vues provoqué par une jointure directe entre la table de contenus et la table de conversions
WITH content_agg AS (
    SELECT creator_id,
           COUNT(content_id) AS post_count,
           SUM(view_count)   AS total_view
    FROM dwd_content_post
    WHERE publish_time >= '2026-01-01'
    GROUP BY creator_id
),
convert_agg AS (
    SELECT p.creator_id,
           COUNT(DISTINCT u.user_id) AS total_register_user
    FROM dwd_content_post p
    JOIN dwd_user_convert u
      ON p.content_id = u.content_id
     AND u.convert_type = 'register'
    WHERE p.publish_time >= '2026-01-01'
    GROUP BY p.creator_id
)
SELECT c.creator_id,
       c.platform,
       c.account_level,
       COALESCE(ca.post_count, 0)          AS post_count,
       COALESCE(ca.total_view, 0)          AS total_view,
       COALESCE(cv.total_register_user, 0) AS total_register_user,
       ROUND(COALESCE(cv.total_register_user, 0) / NULLIF(ca.total_view, 0), 6) AS convert_rate
FROM dim_creator c
LEFT JOIN content_agg ca ON c.creator_id = ca.creator_id
LEFT JOIN convert_agg cv ON c.creator_id = cv.creator_id
ORDER BY total_register_user DESC;



-- @query q2
-- Scénario 2 : segmentation du cycle de vie des créateurs
-- Consigne : d'abord réduire la granularité à « créateur × mois » dans une CTE et précalculer le nombre de mois actifs, puis segmenter selon l'évolution mensuelle
WITH creator_monthly AS (
    SELECT creator_id,
           DATE_FORMAT(publish_time, '%Y-%m') AS month,
           COUNT(content_id) AS monthly_post,
           SUM(view_count)   AS monthly_view
    FROM dwd_content_post
    GROUP BY creator_id, DATE_FORMAT(publish_time, '%Y-%m')
),
creator_trend AS (
    SELECT creator_id,
           month,
           monthly_post,
           monthly_view,
           COUNT(month) OVER (PARTITION BY creator_id) AS active_month_count,
           AVG(monthly_post) OVER (PARTITION BY creator_id
                                   ORDER BY month ROWS 2 PRECEDING) AS avg_post_3m,
           (monthly_view - LAG(monthly_view, 1) OVER (PARTITION BY creator_id ORDER BY month))
             / NULLIF(LAG(monthly_view, 1) OVER (PARTITION BY creator_id ORDER BY month), 0) AS view_growth_rate
    FROM creator_monthly
)
SELECT creator_id,
       active_month_count,
       ROUND(view_growth_rate, 4) AS view_growth_rate,
       CASE
           WHEN active_month_count <= 2                       THEN 'Débutant'
           WHEN view_growth_rate > 0.2                        THEN 'En croissance'
           WHEN view_growth_rate BETWEEN -0.1 AND 0.2         THEN 'Maturité'
           WHEN view_growth_rate < -0.1                        THEN 'Déclin'
       END AS life_cycle_stage
FROM creator_trend
WHERE month = '2026-10'
GROUP BY creator_id, active_month_count, view_growth_rate
ORDER BY life_cycle_stage, view_growth_rate DESC;



-- @query q3
-- Scénario 3 : évaluation de la valeur de croissance par type de contenu
-- Consigne : agréger séparément les vues, les inscriptions et les budgets, pour empêcher la répétition du budget après jointure avec le détail des conversions
WITH content_stat AS (
    SELECT game_category, content_type,
           COUNT(DISTINCT content_id) AS content_num,
           SUM(view_count)            AS total_view
    FROM dwd_content_post
    WHERE publish_time BETWEEN '2026-06-01' AND '2026-10-31'
    GROUP BY game_category, content_type
),
convert_stat AS (
    SELECT p.game_category, p.content_type,
           COUNT(DISTINCT u.user_id) AS register_user_num
    FROM dwd_content_post p
    JOIN dwd_user_convert u
      ON p.content_id = u.content_id AND u.convert_type = 'register'
    WHERE p.publish_time BETWEEN '2026-06-01' AND '2026-10-31'
    GROUP BY p.game_category, p.content_type
),
budget_stat AS (
    SELECT p.game_category, p.content_type,
           SUM(c.budget) AS total_budget
    FROM dwd_content_post p
    JOIN dwd_campaign_put c ON p.content_id = c.content_id
    WHERE p.publish_time BETWEEN '2026-06-01' AND '2026-10-31'
    GROUP BY p.game_category, p.content_type
)
SELECT cs.game_category,
       cs.content_type,
       cs.content_num,
       cs.total_view,
       COALESCE(cv.register_user_num, 0) AS register_user_num,
       ROUND(COALESCE(cv.register_user_num, 0) / NULLIF(cs.total_view, 0), 6) AS register_rate,
       ROUND(bs.total_budget / NULLIF(cv.register_user_num, 0), 2) AS cost_per_register
FROM content_stat cs
LEFT JOIN convert_stat cv
       ON cs.game_category = cv.game_category AND cs.content_type = cv.content_type
LEFT JOIN budget_stat bs
       ON cs.game_category = bs.game_category AND cs.content_type = bs.content_type
ORDER BY register_rate DESC;



-- @query q4
-- Scénario 4 : surveillance globale de l’écosystème de contenu par plateforme
-- Consigne : utiliser une fonction de fenêtrage sur l’agrégat pour calculer creator_share ; agréger d’abord par plateforme avant de calculer les parts, sans sous-requête imbriquée
SELECT c.platform,
       COUNT(DISTINCT c.creator_id) AS creator_count,
       COUNT(DISTINCT p.content_id)  AS total_post,
       SUM(p.view_count)             AS total_view,
       ROUND(SUM(p.view_count) / COUNT(DISTINCT p.content_id), 0) AS avg_view_per_post,
       ROUND(COUNT(DISTINCT c.creator_id)
             / SUM(COUNT(DISTINCT c.creator_id)) OVER (), 4) AS creator_share
FROM dim_creator c
LEFT JOIN dwd_content_post p
       ON c.creator_id = p.creator_id
      AND p.publish_time >= '2026-01-01'
GROUP BY c.platform
ORDER BY total_view DESC;



-- @query q5
-- Scénario 5 : sélection des créateurs à haute valeur pour les campagnes de diffusion
-- Consigne : agréger séparément budgets et inscriptions ; le classement s’effectue au sein de chaque plateforme pour éviter les comparaisons inter-plateformes ; filtre sur au moins 50 inscriptions pour limiter les distorsions liées aux petits échantillons
WITH creator_budget AS (
    SELECT p.creator_id, SUM(cp.budget) AS total_budget
    FROM dwd_content_post p
    JOIN dwd_campaign_put cp ON p.content_id = cp.content_id
    GROUP BY p.creator_id
),
creator_register AS (
    SELECT p.creator_id, COUNT(DISTINCT u.user_id) AS total_register
    FROM dwd_content_post p
    JOIN dwd_campaign_put cp ON p.content_id = cp.content_id
    JOIN dwd_user_convert u
      ON p.content_id = u.content_id AND u.convert_type = 'register'
    GROUP BY p.creator_id
)
SELECT c.creator_id,
       c.platform,
       c.fan_count,
       ROUND(cb.total_budget, 2)                     AS total_budget,
       cr.total_register,
       ROUND(cb.total_budget / cr.total_register, 2) AS cpa,
       RANK() OVER (PARTITION BY c.platform
                    ORDER BY cb.total_budget / cr.total_register ASC) AS platform_cpa_rank
FROM dim_creator c
JOIN creator_budget   cb ON c.creator_id = cb.creator_id
JOIN creator_register cr ON c.creator_id = cr.creator_id
WHERE cr.total_register >= 50
ORDER BY cpa ASC;
