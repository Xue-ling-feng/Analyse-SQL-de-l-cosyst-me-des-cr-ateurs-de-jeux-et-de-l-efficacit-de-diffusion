-- ============================================================
-- Script de création des tables : analyse de l'écosystème des créateurs de jeux et de l'efficacité des diffusions de contenu
-- Compatibilité : MySQL 8.0+ / PostgreSQL 15+ (remplacer DATETIME par TIMESTAMP pour PostgreSQL)
-- Ordre d'exécution : créer les tables d'abord, puis importer les quatre fichiers CSV du dossier dataset/
-- ============================================================


DROP TABLE IF EXISTS dwd_campaign_put;
DROP TABLE IF EXISTS dwd_user_convert;
DROP TABLE IF EXISTS dwd_content_post;
DROP TABLE IF EXISTS dim_creator;


-- Table de dimension des informations de base des créateurs
CREATE TABLE dim_creator (
  creator_id    VARCHAR(16)  NOT NULL COMMENT 'Identifiant unique du créateur',
  platform      VARCHAR(16)  NOT NULL COMMENT 'Plateforme : Douyin / Bilibili / MiHoYo Community / TapTap',
  account_level VARCHAR(8)           COMMENT 'Niveau du compte L1-L5',
  register_time DATE                 COMMENT 'Date d’inscription',
  fan_count     INT                  COMMENT 'Nombre d’abonnés',
  PRIMARY KEY (creator_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Table de dimension des informations de base des créateurs';


-- Table de détail des publications de contenu
CREATE TABLE dwd_content_post (
  content_id    VARCHAR(16) NOT NULL COMMENT 'Identifiant unique du contenu',
  creator_id    VARCHAR(16) NOT NULL COMMENT 'Créateur propriétaire du contenu',
  game_category VARCHAR(32)          COMMENT 'Jeu associé',
  content_type  VARCHAR(16)         COMMENT 'Type de contenu : guide de personnage / guide de mise à jour / création dérivée / gameplay',
  publish_time  DATETIME             COMMENT 'Date et heure de publication',
  view_count    INT                  COMMENT 'Nombre de vues',
  like_count    INT                  COMMENT 'Nombre de likes',
  share_count   INT                 COMMENT 'Nombre de partages',
  PRIMARY KEY (content_id),
  KEY idx_creator (creator_id),
  KEY idx_publish (publish_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Table de détail des publications de contenu';


-- Table des conversions utilisateur (seul le type register est utilisé dans ce projet ; convert_type prévoit click / download)
CREATE TABLE dwd_user_convert (
  convert_id   VARCHAR(16) NOT NULL COMMENT 'Identifiant unique de l’événement de conversion',
  content_id   VARCHAR(16) NOT NULL COMMENT 'Contenu source de la conversion',
  user_id      VARCHAR(16) NOT NULL COMMENT 'Identifiant utilisateur (unique pour un même contenu)',
  convert_type VARCHAR(16)          COMMENT 'Type de conversion : register',
  convert_time DATETIME             COMMENT 'Date et heure de la conversion',
  PRIMARY KEY (convert_id),
  KEY idx_content (content_id),
  KEY idx_type (convert_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Table de détail des conversions utilisateur';


-- Table des plans de diffusion (un seul plan par contenu pour éviter le double comptage du budget)
CREATE TABLE dwd_campaign_put (
  campaign_id   VARCHAR(16) NOT NULL COMMENT 'Identifiant unique du plan de diffusion',
  content_id    VARCHAR(16) NOT NULL COMMENT 'Contenu diffusé',
  budget        DECIMAL(12,2)        COMMENT 'Budget de diffusion (yuan)',
  put_time      DATE                 COMMENT 'Date de lancement de la diffusion',
  target_region VARCHAR(16)          COMMENT 'Région cible',
  PRIMARY KEY (campaign_id),
  UNIQUE KEY uk_content (content_id),
  KEY idx_put (put_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Table des plans de diffusion';
