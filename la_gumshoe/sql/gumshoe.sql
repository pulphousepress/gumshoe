-- sql/gumshoe.sql
-- Schema for la_gumshoe (dead investigations)
-- Supports MySQL / MariaDB. Uses JSON column for scene_data (MySQL 5.7+).
-- If your server doesn't support JSON, create scene_data_text column instead (example below).

CREATE TABLE IF NOT EXISTS `dead_investigations` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `victim_type` ENUM('player','npc') NOT NULL DEFAULT 'npc',
  `victim_identifier` VARCHAR(128) NULL,
  `death_time` DATETIME NOT NULL,
  `estimated_time_of_death` DATETIME NULL,
  `cause` VARCHAR(64) DEFAULT 'unknown',
  `critical_area` VARCHAR(32) DEFAULT 'unknown',
  `attacker_identifier` VARCHAR(128) NULL,
  `scene_data` JSON NULL,
  `investigator_id` VARCHAR(64) NULL,
  `xp_awarded` INT DEFAULT 0,
  `payout` INT DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_victim_identifier` (`victim_identifier`),
  INDEX `idx_death_time` (`death_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Fallback: if your MySQL version does not support JSON, you can use:
-- ALTER TABLE `dead_investigations` ADD COLUMN `scene_data_text` TEXT NULL;
-- and use that column instead.
