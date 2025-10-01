# Complete Church Signup Website Setup Guide

## Project Structure
```
church-signup/
├── backend/
│   ├── server.js
│   ├── database.sql
│   ├── .env
│   ├── package.json
│   └── README.md
├── frontend/
│   ├── public/
│   ├── src/
│   │   ├── App.js
│   │   ├── index.js
│   │   └── index.css
│   ├── package.json
│   └── README.md
└── README.md
```

---

## STEP 1: Install Prerequisites

### Install Node.js
1. Go to https://nodejs.org/
2. Download and install the LTS version (v18 or higher)
3. Verify installation:
```bash
node --version
npm --version
```

### Install MySQL
1. Go to https://dev.mysql.com/downloads/mysql/
2. Download and install MySQL Community Server
3. During installation, remember your root password
4. Verify installation:
```bash
mysql --version
```

---

## STEP 2: Set Up the Database

### 1. Create the database
Open MySQL command line or MySQL Workbench and run:

```sql
CREATE DATABASE church_db;
USE church_db;

-- Members table
CREATE TABLE members (
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
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Ministry interests table
CREATE TABLE member_ministries (
  id INT PRIMARY KEY AUTO_INCREMENT,
  member_id INT NOT NULL,
  ministry_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX idx_email ON members(email);
CREATE INDEX idx_created_at ON members(created_at);
CREATE INDEX idx_member_id ON member_ministries(member_id);
```

---

## STEP 3: Set Up the Backend

### 1. Create backend folder and initialize
```bash
mkdir church-signup
cd church-signup
mkdir backend
cd backend
npm init -y
```

### 2. Install backend dependencies
```bash
npm install express cors mysql2 dotenv nodemailer
npm install --save-dev nodemon
```

### 3. Create server.js file
Create `backend/server.js` with this content:

```javascript
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

// Test database connection
pool.getConnection()
  .then(connection => {
    console.log('✅ Database connected successfully');
    connection.release();
  })
  .catch(err => {
    console.error('❌ Database connection failed:', err.message);
  });

// Email transporter (optional - comment out if not using email)
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
        how_did_you_hear
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
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

    // Send confirmation email (optional)
    if (process.env.EMAIL_USER) {
      try {
        await sendConfirmationEmail(email, firstName);
      } catch (emailError) {
        console.error('Email sending failed:', emailError);
      }
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

// Send confirmation email function
async function sendConfirmationEmail(email, firstName) {
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
            <li>Our pastoral team will reach out within 48 hours</li>
            <li>You'll receive information about upcoming services</li>
            <li>Check your email for weekly updates</li>
          </ul>
        </div>
        
        <p>If you have any questions, feel free to reply to this email or call us.</p>
        
        <p style="color: #6b7280;">Blessings,<br>The Church Team</p>
      </div>
    `
  };

  await transporter.sendMail(mailOptions);
}

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
});
```

### 4. Create .env file
Create `backend/.env`:

```env
# Database Configuration
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password_here
DB_NAME=church_db

# Server Configuration
PORT=5000

# Email Configuration (Optional - for sending confirmation emails)
EMAIL_USER=your_email@gmail.com
EMAIL_PASSWORD=your_app_password_here
```

### 5. Update package.json
Add scripts to `backend/package.json`:

```json
{
  "name": "church-backend",
  "version": "1.0.0",
  "description": "Church signup backend API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "mysql2": "^3.6.0",
    "dotenv": "^16.3.1",
    "nodemailer": "^6.9.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

---

## STEP 4: Set Up the Frontend

### 1. Create React app
```bash
cd ..  # Go back to church-signup folder
npx create-react-app frontend
cd frontend
```

### 2. Install frontend dependencies
```bash
npm install lucide-react
```

### 3. Replace src/App.js
Replace the content of `frontend/src/App.js` with the church signup component code (provided earlier).

### 4. Update src/index.css
Replace `frontend/src/index.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

* {
  box-sizing: border-box;
}
```

### 5. Install and configure Tailwind CSS
```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

Update `frontend/tailwind.config.js`:

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

---

## STEP 5: Run the Application

### 1. Start the Backend Server
Open a terminal in the backend folder:
```bash
cd backend
npm run dev
```

You should see:
```
🚀 Server running on http://localhost:5000
✅ Database connected successfully
```

### 2. Start the Frontend
Open a NEW terminal in the frontend folder:
```bash
cd frontend
npm start
```

The website should automatically open at `http://localhost:3000`

---

## STEP 6: Test the Application

### Test Signup
1. Fill out the form on `http://localhost:3000`
2. Click "Join Our Church Family"
3. Check the browser console for success message
4. Verify data in MySQL:
```sql
USE church_db;
SELECT * FROM members;
SELECT * FROM member_ministries;
```

### Test API Endpoints
```bash
# Health check
curl http://localhost:5000/api/health

# Get all members
curl http://localhost:5000/api/members

# Get specific member
curl http://localhost:5000/api/members/1
```

---

## STEP 7: Deploy to Production

### Option A: Deploy to Heroku (Free tier available)

#### Backend Deployment:
```bash
# Install Heroku CLI
# Create Heroku app
heroku create your-church-api

# Add MySQL addon
heroku addons:create jawsdb:kitefin

# Get database URL
heroku config:get JAWSDB_URL

# Update your .env with production DB
# Deploy
git push heroku main
```

#### Frontend Deployment:
```bash
# Build React app
npm run build

# Deploy to Netlify, Vercel, or GitHub Pages
# Update API URL to your Heroku backend
```

### Option B: Deploy to AWS/DigitalOcean

1. Set up an EC2 instance or Droplet
2. Install Node.js and MySQL
3. Clone your repository
4. Set up environment variables
5. Use PM2 to keep the server running
6. Set up Nginx as reverse proxy
7. Get SSL certificate with Let's Encrypt

### Option C: Use Shared Hosting

1. Use cPanel with Node.js support
2. Upload backend files
3. Build React app: `npm run build`
4. Upload build folder to public_html
5. Configure database connection

---

## Troubleshooting

### Database Connection Issues
```bash
# Check MySQL is running
sudo systemctl status mysql  # Linux
# or
mysql.server status  # Mac

# Test connection
mysql -u root -p
```

### Port Already in Use
```bash
# Find process on port 5000
lsof -i :5000  # Mac/Linux
netstat -ano | findstr :5000  # Windows

# Kill the process
kill -9 <PID>
```

### CORS Errors
Make sure backend has:
```javascript
app.use(cors());
```

And frontend API URL matches backend URL.

---

## Security Best Practices

1. **Environment Variables**: Never commit `.env` files
2. **Password Hashing**: If adding authentication, use bcrypt
3. **Input Validation**: Validate all inputs on backend
4. **SQL Injection**: Use parameterized queries (already done)
5. **Rate Limiting**: Add rate limiting to prevent abuse
6. **HTTPS**: Always use HTTPS in production
7. **Database Backups**: Set up regular backups

---

## Optional Enhancements

### Add Admin Dashboard
Create an admin panel to view/manage members

### Add Email Notifications
Configure nodemailer with Gmail or SendGrid

### Add Authentication
Implement JWT authentication for admin access

### Add Payment Integration
Use Stripe for online tithes/donations

### Add Calendar Integration
Google Calendar API for events

---

## Support & Resources

- **React Documentation**: https://react.dev/
- **Express Documentation**: https://expressjs.com/
- **MySQL Documentation**: https://dev.mysql.com/doc/
- **Tailwind CSS**: https://tailwindcss.com/docs

---

## Maintenance Checklist

- [ ] Regular database backups
- [ ] Monitor server logs
- [ ] Update dependencies monthly
- [ ] Test signup form weekly
- [ ] Review member data monthly
- [ ] Update SSL certificates (if self-managed)
- [ ] Monitor email deliverability

---

**Congratulations! Your church signup website is now functional! 🎉**