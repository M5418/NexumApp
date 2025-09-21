# Nexum Backend API

A complete REST API for the Nexum social networking application built with Node.js, Express, MySQL, and AWS S3.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your database and AWS credentials

# Run database migrations
npm run prisma:migrate

# Start development server
npm run dev

# Start production server
npm start
```

## 📚 API Documentation

### Base URL
```
http://localhost:8080/api
```

### Authentication
All protected endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

---

## 🔐 Authentication Endpoints

### POST /api/auth/signup
Register a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "token": "jwt_token_here",
    "user": {
      "id": 1,
      "email": "user@example.com"
    }
  }
}
```

### POST /api/auth/login
Authenticate existing user.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "token": "jwt_token_here",
    "user": {
      "id": 1,
      "email": "user@example.com"
    }
  }
}
```

### GET /api/auth/me
Get current user information. **Requires authentication.**

**Response:**
```json
{
  "ok": true,
  "data": {
    "id": 1,
    "email": "user@example.com"
  }
}
```

### POST /api/auth/logout
Logout current user (client-side token removal).

**Response:**
```json
{
  "ok": true,
  "data": {}
}
```

---

## 👤 Profile Endpoints

### GET /api/profile/me
Get current user's complete profile. **Requires authentication.**

**Response:**
```json
{
  "ok": true,
  "data": {
    "user_id": 1,
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "username": "johndoe",
    "birthday": "1990-01-01",
    "gender": "male",
    "professional_experiences": [
      {"title": "Software Engineer"}
    ],
    "trainings": [
      {"title": "Computer Science", "subtitle": "University of Toronto"}
    ],
    "bio": "Passionate developer",
    "status": "Looking for opportunities",
    "interest_domains": ["technology", "sports"],
    "street": "123 Main St",
    "city": "Toronto",
    "state": "ON",
    "postal_code": "M5V 3A8",
    "country": "Canada",
    "profile_photo_url": "https://...",
    "cover_photo_url": "https://..."
  }
}
```

### PATCH /api/profile
Update current user's profile. **Requires authentication.**

**Request Body (all fields optional):**
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "username": "johndoe",
  "birthday": "1990-01-01",
  "gender": "male",
  "professional_experiences": [
    {"title": "Software Engineer"},
    {"title": "Full Stack Developer"}
  ],
  "trainings": [
    {"title": "Computer Science", "subtitle": "University of Toronto"}
  ],
  "bio": "Passionate developer with 5 years experience",
  "status": "Open to work",
  "interest_domains": ["technology", "sports", "music"],
  "street": "123 Main St",
  "city": "Toronto",
  "state": "ON",
  "postal_code": "M5V 3A8",
  "country": "Canada",
  "profile_photo_url": "https://nexum-uploads.s3.ca-central-1.amazonaws.com/...",
  "cover_photo_url": "https://nexum-uploads.s3.ca-central-1.amazonaws.com/..."
}
```

**Response:**
```json
{
  "ok": true,
  "data": {}
}
```

---

## 👥 Users Endpoints

### GET /api/users/all
Get all users (excluding current user) for connections. **Requires authentication.**

**Response:**
```json
{
  "ok": true,
  "data": [
    {
      "id": 2,
      "name": "Jane Smith",
      "username": "@janesmith",
      "email": "jane@example.com",
      "avatarUrl": "https://...",
      "coverUrl": "https://...",
      "bio": "Designer and developer",
      "status": "Available for freelance",
      "avatarLetter": "J"
    }
  ]
}
```

---

## 🤝 Connections Endpoints

### GET /api/connections
Get current user's connections. **Requires authentication.**

**Response:**
```json
{
  "ok": true,
  "data": {
    "inbound": [2, 3, 4],
    "outbound": [5, 6, 7]
  }
}
```

### POST /api/connections/:userId
Create a connection to another user. **Requires authentication.**

**Response:**
```json
{
  "ok": true,
  "data": {}
}
```

### DELETE /api/connections/:userId
Remove a connection to another user. **Requires authentication.**

**Response:**
```json
{
  "ok": true,
  "data": {}
}
```

---

## 📁 File Upload Endpoints

### POST /api/files/presign-upload
Get a presigned URL for uploading files to S3. **Requires authentication.**

**Request Body:**
```json
{
  "ext": "jpg"
}
```

**Supported Extensions:** jpg, jpeg, png, webp, pdf

**Response:**
```json
{
  "ok": true,
  "data": {
    "key": "u/1/2024/01/15/uuid.jpg",
    "putUrl": "https://nexum-uploads.s3.ca-central-1.amazonaws.com/...",
    "publicUrl": "https://nexum-uploads.s3.ca-central-1.amazonaws.com/u/1/2024/01/15/uuid.jpg"
  }
}
```

### POST /api/files/confirm
Confirm successful file upload. **Requires authentication.**

**Request Body:**
```json
{
  "key": "u/1/2024/01/15/uuid.jpg",
  "url": "https://nexum-uploads.s3.ca-central-1.amazonaws.com/u/1/2024/01/15/uuid.jpg"
}
```

**Response:**
```json
{
  "ok": true,
  "data": {}
}
```

### GET /api/files/list
List user's uploaded files. **Requires authentication.**

**Query Parameters:**
- `limit` (optional): Number of files to return (max 100, default 50)
- `cursor` (optional): Pagination cursor

**Response:**
```json
{
  "ok": true,
  "data": [
    {
      "key": "u/1/2024/01/15/uuid.jpg",
      "size": 1024000,
      "lastModified": "2024-01-15T10:30:00.000Z"
    }
  ],
  "meta": {
    "nextCursor": "u/1/2024/01/15/uuid.jpg"
  }
}
```

---

## 🏥 Health Check Endpoints

### GET /health
Basic health check.

**Response:**
```json
{
  "ok": true
}
```

### GET /healthz
Kubernetes-style health check.

**Response:**
```json
{
  "ok": true
}
```

---

## 🔧 Environment Variables

```env
PORT=8080
DATABASE_URL=mysql://user:password@host:3306/database
AWS_REGION=ca-central-1
S3_BUCKET=nexum-uploads
JWT_SECRET=your-secret-key-here
```

## 🗄️ Database Schema

The API uses MySQL with the following main tables:
- `users` - User accounts and authentication
- `profiles` - User profile information
- `connections` - Social connections between users
- `uploads` - File upload tracking

## 🚀 Deployment

### Docker
```bash
# Build image
docker build -t nexum-backend .

# Run container
docker run -p 8080:8080 --env-file .env nexum-backend
```

### AWS EC2
1. Set up EC2 instance with Node.js
2. Configure RDS MySQL database
3. Set up S3 bucket for file uploads
4. Deploy using PM2 or similar process manager

## 🔒 Security Features

- JWT-based authentication with 7-day expiry
- bcrypt password hashing (12 rounds)
- Input validation using Zod schemas
- CORS protection
- SQL injection prevention via parameterized queries
- File upload restrictions (type and size)

## 📊 API Response Format

All API responses follow this consistent format:

**Success Response:**
```json
{
  "ok": true,
  "data": { ... },
  "meta": { ... } // Optional pagination/metadata
}
```

**Error Response:**
```json
{
  "ok": false,
  "error": "error_code_here"
}
```

## 🐛 Common Error Codes

- `validation_error` - Invalid request data
- `unauthorized` - Missing or invalid authentication
- `invalid_token` - JWT token is invalid or expired
- `email_already_exists` - Email already registered
- `invalid_credentials` - Wrong email/password
- `username_taken` - Username already in use
- `invalid_file_extension` - Unsupported file type
- `internal_error` - Server error

## 🧪 Testing

```bash
# Test authentication
curl -X POST http://localhost:8080/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Test with authentication
curl -X GET http://localhost:8080/api/profile/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```
