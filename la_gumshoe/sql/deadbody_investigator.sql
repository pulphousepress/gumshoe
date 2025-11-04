-- gumshoe deadbody investigator schema
-- apply with: mysql -h <host> -u <user> -p<pass> <database> < la_gumshoe/sql/deadbody_investigator.sql

START TRANSACTION;

CREATE TABLE IF NOT EXISTS `gumshoe_investigations` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `victim_type` VARCHAR(32) NOT NULL DEFAULT 'npc',
    `victim_identifier` VARCHAR(191) NULL,
    `death_time` DATETIME NOT NULL,
    `estimated_time_of_death` DATETIME NULL,
    `cause` VARCHAR(191) NOT NULL DEFAULT 'unknown',
    `critical_area` VARCHAR(191) NOT NULL DEFAULT 'unknown',
    `attacker_identifier` VARCHAR(191) NULL,
    `scene_data` LONGTEXT NULL,
    `scene_data_json` JSON NULL,
    `investigator_identifier` VARCHAR(191) NOT NULL,
    `xp_awarded` INT NOT NULL DEFAULT 0,
    `payout` INT NOT NULL DEFAULT 0,
    `metadata` LONGTEXT NULL,
    `casefile_id` BIGINT UNSIGNED NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_gumshoe_investigator` (`investigator_identifier`),
    INDEX `idx_gumshoe_casefile` (`casefile_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `casefile_investigations` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `casefile_id` BIGINT UNSIGNED NOT NULL,
    `investigation_id` BIGINT UNSIGNED NOT NULL,
    `linked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_casefile_investigation` (`casefile_id`, `investigation_id`),
    CONSTRAINT `fk_casefile_investigation_investigation`
        FOREIGN KEY (`investigation_id`) REFERENCES `gumshoe_investigations`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `gumshoe_investigations`
    (`victim_type`, `victim_identifier`, `death_time`, `cause`, `critical_area`, `investigator_identifier`, `scene_data`, `scene_data_json`)
VALUES
    ('npc', 'sample_npc_001', NOW(), 'gunshot', 'torso', 'console_tester', '{"notes":"initial seed"}', JSON_OBJECT('notes', 'initial seed'))
ON DUPLICATE KEY UPDATE `updated_at` = CURRENT_TIMESTAMP;

COMMIT;

-- Rollback commands
-- DELETE FROM `casefile_investigations`;
-- DROP TABLE IF EXISTS `casefile_investigations`;
-- DROP TABLE IF EXISTS `gumshoe_investigations`;
-- Optional: DROP SCHEMA `gumshoe`;
