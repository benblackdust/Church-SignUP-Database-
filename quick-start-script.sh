#!/bin/bash

# Church Signup Website - Quick Start Installation Script
# This script automates the setup process

echo "🏛️  Church Signup Website - Quick Start Installation"
echo "======================================================"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js from https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ NPM version: $(npm --version)"
echo ""

# Check if MySQL is installed
if ! command -v mysql &> /dev/null; then
    echo "⚠️  MySQL is not installed. Please install MySQL from https://dev.mysql.com/downloads/"
    echo "   You can continue without MySQL, but you'll need to install it later."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "Step 1: Creating project structure..."
echo "--------------------------------------"

# Create main project directory
mkdir -p church-signup
cd church-signup

# Create backend directory
mkdir -p backend
cd backend

echo "Step 2: Setting up backend..."
echo "--------------------------------------"

# Initialize backend
npm init -y

# Install backend dependencies
echo "Installing backend dependencies..."
npm install express cors mysql2 dotenv nodemailer
npm install --save-dev nodemon

# Create .env file
cat > .env << EOF
# Database Configuration
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password_here
DB_NAME=church_db

# Server Configuration
PORT=5000

# Email Configuration (Optional)
EMAIL_USER=your_email@gmail.com
EMAIL_PASSWORD=your_app_password_here
EOF

echo "✅ Backend dependencies installed"
echo ""

# Create server.js
cat > server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const nodemailer = require('nodemailer');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'church_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

pool.getConnection()
  .then(connection => {
    console.log('✅ Database connected successfully');
    connection.release();
  })
  .catch(err => {
    console.error('❌ Database connection failed:', err.message);
    console.log('💡 Make sure to configure your .env file with correct database credentials');
  });

app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'Church signup API is running' });
});

app.post('/api/signup', async (req, res) => {
  const {
    firstName, lastName, email, phone, address, city, state, zipCode,
    birthDate, membershipType, ministry, attendancePreference, baptized,
    salvation, emergencyContactName, emergencyContactPhone, prayer, howDidYouHear
  } = req.body;

  if (!firstName || !lastName || !email || !phone || !birthDate) {
    return res.status(400).json({
      error: 'Missing required fields',
      required: ['firstName', 'lastName', 'email', 'phone', 'birthDate']
    });
  }

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

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

    if (ministry && ministry.length > 0) {
      const ministryValues = ministry.map(m => [memberId, m]);
      await connection.query(
        'INSERT INTO member_ministries (member_id, ministry_name) VALUES ?',
        [ministryValues]
      );
    }

    await connection.commit();

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

app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
});
EOF

# Update package.json scripts
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = {
  start: 'node server.js',
  dev: 'nodemon server.js'
};
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"

echo "✅ Backend setup complete"
echo ""

# Go back to main directory
cd ..

echo "Step 3: Setting up frontend..."
echo "--------------------------------------"

# Create React app
npx create-react-app frontend

cd frontend

# Install frontend dependencies
echo "Installing frontend dependencies..."
npm install lucide-react

# Install Tailwind CSS
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p

# Configure Tailwind
cat > tailwind.config.js << EOF
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
EOF

# Update index.css
cat > src/index.css << EOF
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
EOF

echo "✅ Frontend setup complete"
echo ""

cd ..

# Create database setup file
cat > setup-database.sql << EOF
CREATE DATABASE IF NOT EXISTS church_db;
USE church_db;

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
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS member_ministries (
  id INT PRIMARY KEY AUTO_INCREMENT,
  member_id INT NOT NULL,
  ministry_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
);

CREATE INDEX idx_email ON members(email);
CREATE INDEX idx_created_at ON members(created_at);
CREATE INDEX idx_member_id ON member_ministries(member_id);
EOF

# Create README
cat > README.md << EOF
# Church Signup Website

## Quick Start

### 1. Configure Database
Edit \`backend/.env\` and set your MySQL password:
\`\`\`
DB_PASSWORD=your_mysql_password
\`\`\`

### 2. Setup Database
Run the SQL script:
\`\`\`bash
mysql -u root -p < setup-database.sql
\`\`\`

### 3. Start Backend Server
\`\`\`bash
cd backend
npm run dev
\`\`\`

### 4. Start Frontend (in a new terminal)
\`\`\`bash
cd frontend
npm start
\`\`\`

### 5. Open Browser
Navigate to http://localhost:3000

## Project Structure
- \`backend/\` - Node.js/Express API server
- \`frontend/\` - React application
- \`setup-database.sql\` - Database schema

## Next Steps
1. Copy the React component code into \`frontend/src/App.js\`
2. Configure email settings in \`backend/.env\` (optional)
3. Test the signup form
4. Deploy to production

## Support
For issues or questions, refer to the complete setup guide.
EOF

echo ""
echo "======================================================"
echo "✅ Installation Complete!"
echo "======================================================"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Configure database:"
echo "   Edit backend/.env and set your MySQL password"
echo ""
echo "2. Setup database:"
echo "   mysql -u root -p < setup-database.sql"
echo ""
echo "3. Copy the React component code into frontend/src/App.js"
echo ""
echo "4. Start the backend:"
echo "   cd backend && npm run dev"
echo ""
echo "5. Start the frontend (in a new terminal):"
echo "   cd frontend && npm start"
echo ""
echo "6. Open http://localhost:3000 in your browser"
echo ""
echo "📖 For detailed instructions, see README.md"
echo ""
EOF

chmod +x quick-start.sh

echo "✅ Quick start script created!"
echo ""