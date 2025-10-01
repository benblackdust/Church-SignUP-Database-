// server.js
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const nodemailer = require('nodemailer');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Database connection pool
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'church_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Email transporter configuration
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD
  }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'Church signup API is running' });
});

// Signup endpoint
app.post('/api/signup', async (req, res) => {
  const {
    firstName,
    lastName,
    email,
    phone,
    address,
    city,
    state,
    zipCode,
    birthDate,
    membershipType,
    ministry,
    attendancePreference,
    baptized,
    salvation,
    emergencyContactName,
    emergencyContactPhone,
    prayer,
    howDidYouHear
  } = req.body;

  // Validation
  if (!firstName || !lastName || !email || !phone || !birthDate) {
    return res.status(400).json({
      error: 'Missing required fields',
      required: ['firstName', 'lastName', 'email', 'phone', 'birthDate']
    });
  }

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    // Insert into members table
    const [result] = await connection.execute(
      `INSERT INTO members (
        first_name, last_name, email, phone, address, city, state, zip_code,
        birth_date, membership_type, attendance_preference, baptized, salvation,
        emergency_contact_name, emergency_contact_phone, prayer_request,
        how_did_you_hear, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        firstName, lastName, email, phone, address, city, state, zipCode,
        birthDate, membershipType, attendancePreference, baptized, salvation,
        emergencyContactName, emergencyContactPhone, prayer, howDidYouHear
      ]
    );

    const memberId = result.insertId;

    // Insert ministry interests
    if (ministry && ministry.length > 0) {
      const ministryValues = ministry.map(m => [memberId, m]);
      await connection.query(
        'INSERT INTO member_ministries (member_id, ministry_name) VALUES ?',
        [ministryValues]
      );
    }

    await connection.commit();

    // Send confirmation email
    try {
      await sendConfirmationEmail(email, firstName, lastName);
    } catch (emailError) {
      console.error('Email sending failed:', emailError);
      // Don't fail the request if email fails
    }

    // Send notification to church staff
    try {
      await sendStaffNotification({
        firstName, lastName, email, phone, membershipType
      });
    } catch (staffEmailError) {
      console.error('Staff notification failed:', staffEmailError);
    }

    res.status(201).json({
      success: true,
      message: 'Signup successful',
      memberId: memberId
    });

  } catch (error) {
    await connection.rollback();
    console.error('Signup error:', error);
    
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        error: 'Email already registered',
        message: 'This email is already in our system'
      });
    }
    
    res.status(500).json({
      error: 'Signup failed',
      message: 'An error occurred during signup. Please try again.'
    });
  } finally {
    connection.release();
  }
});

// Get all members (admin endpoint)
app.get('/api/members', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT m.*, 
        GROUP_CONCAT(mm.ministry_name) as ministries
      FROM members m
      LEFT JOIN member_ministries mm ON m.id = mm.member_id
      GROUP BY m.id
      ORDER BY m.created_at DESC`
    );

    res.json({
      success: true,
      count: rows.length,
      members: rows
    });
  } catch (error) {
    console.error('Error fetching members:', error);
    res.status(500).json({
      error: 'Failed to fetch members'
    });
  }
});

// Get member by ID
app.get('/api/members/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const [rows] = await pool.execute(
      `SELECT m.*, 
        GROUP_CONCAT(mm.ministry_name) as ministries
      FROM members m
      LEFT JOIN member_ministries mm ON m.id = mm.member_id
      WHERE m.id = ?
      GROUP BY m.id`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        error: 'Member not found'
      });
    }

    res.json({
      success: true,
      member: rows[0]
    });
  } catch (error) {
    console.error('Error fetching member:', error);
    res.status(500).json({
      error: 'Failed to fetch member'
    });
  }
});

// Send confirmation email to new member
async function sendConfirmationEmail(email, firstName, lastName) {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject: 'Welcome to Our Church Family!',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #7c3aed;">Welcome, ${firstName}!</h2>
        <p>Thank you for joining our church family. We're excited to have you!</p>
        
        <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3 style="margin-top: 0;">What's Next?</h3>
          <ul style="line-height: 1.8;">