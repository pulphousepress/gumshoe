CREATE TABLE `user_notepads` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(64) NOT NULL,
    `note_id` VARCHAR(64) NOT NULL,
    `content` LONGTEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `note_unique` (`identifier`, `note_id`)
);
