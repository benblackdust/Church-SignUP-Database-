-- Church Signup Database Schema
-- MySQL Database Setup

-- Create database
CREATE DATABASE IF NOT EXISTS church_db;
USE church_db;

-- Members table - stores all member information
CREATE TABLE IF NOT EXISTS members (
  id INT PRIMARY KEY AUTO_INCREMENT,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  phone VARCHAR(20) NOT NULL,
  address VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(50),
  zip_code VARCHAR(10),
  birth_date DATE NOT NULL,
  membership_type ENUM('visitor', 'member', 'volunteer') DEFAULT 'member',
  attendance_preference VARCHAR(50),
  baptized VARCHAR(20),
  salvation VARCHAR(20),
  emergency_contact_name VARCHAR(100),
  emergency_contact_phone VARCHAR(20),
  prayer_request TEXT,
  how_did_you_hear VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_email (email),
  INDEX idx_created_at (created_at),
  INDEX idx_membership_type (membership_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ministry interests table - stores member ministry selections
CREATE TABLE IF NOT EXISTS member_ministries (
  id INT PRIMARY KEY AUTO_INCREMENT,
  member_id INT NOT NULL,
  ministry_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
  INDEX idx_member_id (member_id),
  INDEX idx_ministry_name (ministry_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Optional: Create a view for easy member overview
CREATE OR REPLACE VIEW member_overview AS
SELECT 
  m.id,
  m.first_name,
  m.last_name,
  m.email,
  m.phone,
  m.membership_type,
  m.attendance_preference,
  m.baptized,
  m.salvation,
  GROUP_CONCAT(mm.ministry_name SEPARATOR ', ') as ministries,
  m.created_at
FROM members m
LEFT JOIN member_ministries mm ON m.id = mm.member_id
GROUP BY m.id
ORDER BY m.created_at DESC;

-- Optional: Create admin user table (for future admin panel)
CREATE TABLE IF NOT EXISTS admin_users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  role ENUM('admin', 'staff') DEFAULT 'staff',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP NULL,
  INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample data for testing (optional)
-- Remove or comment out in production
INSERT INTO members (
  first_name, last_name, email, phone, address, city, state, zip_code,
  birth_date, membership_type, attendance_preference, baptized, salvation,
  how_did_you_hear
) VALUES (
  'John', 'Doe', 'john.doe@example.com', '555-123-4567',
  '123 Main St', 'Houston', 'TX', '77001',
  '1985-05-15', 'member', 'sunday-morning', 'yes', 'yes',
  'friend'
);

-- Get the ID of the inserted member
SET @member_id = LAST_INSERT_ID();

-- Insert sample ministries for the test member
INSERT INTO member_ministries (member_id, ministry_name) VALUES
(@member_id, 'Worship Team'),
(@member_id, 'Youth Ministry');

-- Useful queries for managing the database

-- View all members with their ministries
SELECT * FROM member_overview;

-- Count members by membership type
SELECT membership_type, COUNT(*) as count
FROM members
GROUP BY membership_type;

-- Count members by how they heard about the church
SELECT how_did_you_hear, COUNT(*) as count
FROM members
WHERE how_did_you_hear IS NOT NULL
GROUP BY how_did_you_hear
ORDER BY count DESC;

-- Find members interested in specific ministry
SELECT m.first_name, m.last_name, m.email, m.phone
FROM members m
JOIN member_ministries mm ON m.id = mm.member_id
WHERE mm.ministry_name = 'Worship Team';

-- Get recent signups (last 30 days)
SELECT first_name, last_name, email, membership_type, created_at
FROM members
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
ORDER BY created_at DESC;

-- Members who need baptism follow-up
SELECT first_name, last_name, email, phone, baptized
FROM members
WHERE baptized IN ('no', 'interested')
ORDER BY created_at DESC;

-- Members who want to learn about salvation
SELECT first_name, last_name, email, phone, salvation
FROM members
WHERE salvation IN ('no', 'unsure')
ORDER BY created_at DESC;

-- Prayer requests (non-empty)
SELECT first_name, last_name, email, phone, prayer_request, created_at
FROM members
WHERE prayer_request IS NOT NULL AND prayer_request != ''
ORDER BY created_at DESC;

-- Backup command (run from terminal)
-- mysqldump -u root -p church_db > church_db_backup_$(date +%Y%m%d).sql

-- Restore from backup (run from terminal)
-- mysql -u root -p church_db < church_db_backup_YYYYMMDD.sql