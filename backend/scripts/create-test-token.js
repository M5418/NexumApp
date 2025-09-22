import 'dotenv/config';
import jwt from 'jsonwebtoken';

// Create a test token for API testing
function createTestToken() {
  // Use one of the existing user IDs from your database
  const testUserId = 'HxgD4fJ8CRSD'; // The user who created the post
  
  const payload = {
    id: testUserId,
    email: 'test@example.com'
  };
  
  const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '24h' });
  
  console.log('🔑 Test JWT Token:');
  console.log(token);
  console.log('\n📋 Use this token for API testing:');
  console.log(`curl -H "Authorization: Bearer ${token}" http://localhost:8080/api/posts`);
  
  return token;
}

createTestToken();
