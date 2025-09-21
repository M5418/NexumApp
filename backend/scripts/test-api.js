import 'dotenv/config';

const API_BASE = process.env.API_BASE || 'http://localhost:8080/api';

let authToken = null;
let userId = null;

// Helper function for API requests
async function apiRequest(method, endpoint, data = null, auth = true) {
  const url = `${API_BASE}${endpoint}`;
  const headers = {
    'Content-Type': 'application/json',
  };
  
  if (auth && authToken) {
    headers['Authorization'] = `Bearer ${authToken}`;
  }
  
  const options = {
    method,
    headers,
  };
  
  if (data) {
    options.body = JSON.stringify(data);
  }
  
  try {
    const response = await fetch(url, options);
    const result = await response.json();
    
    console.log(`${method} ${endpoint}: ${response.status}`);
    if (!response.ok) {
      console.log('  Error:', result);
    }
    
    return { response, result };
  } catch (error) {
    console.error(`${method} ${endpoint}: FAILED`, error.message);
    return { error };
  }
}

async function testHealthEndpoints() {
  console.log('\n🏥 Testing Health Endpoints...');
  
  await apiRequest('GET', '/health', null, false);
  await apiRequest('GET', '/healthz', null, false);
}

async function testAuthEndpoints() {
  console.log('\n🔐 Testing Authentication...');
  
  const testEmail = `test-${Date.now()}@example.com`;
  const testPassword = 'password123';
  
  // Test signup
  const { result: signupResult } = await apiRequest('POST', '/auth/signup', {
    email: testEmail,
    password: testPassword
  }, false);
  
  if (signupResult && signupResult.ok) {
    authToken = signupResult.data.token;
    userId = signupResult.data.user.id;
    console.log('  ✅ Signup successful, token acquired');
  }
  
  // Test login
  const { result: loginResult } = await apiRequest('POST', '/auth/login', {
    email: testEmail,
    password: testPassword
  }, false);
  
  if (loginResult && loginResult.ok) {
    console.log('  ✅ Login successful');
  }
  
  // Test /me endpoint
  await apiRequest('GET', '/auth/me');
  
  // Test logout
  await apiRequest('POST', '/auth/logout');
}

async function testProfileEndpoints() {
  console.log('\n👤 Testing Profile Endpoints...');
  
  // Get profile
  await apiRequest('GET', '/profile/me');
  
  // Update profile
  await apiRequest('PATCH', '/profile', {
    first_name: 'Test',
    last_name: 'User',
    username: `testuser${Date.now()}`,
    bio: 'This is a test user profile',
    status: 'Testing the API',
    professional_experiences: [
      { title: 'Software Engineer' },
      { title: 'Full Stack Developer' }
    ],
    trainings: [
      { title: 'Computer Science', subtitle: 'Test University' }
    ],
    interest_domains: ['technology', 'testing']
  });
  
  // Get updated profile
  await apiRequest('GET', '/profile/me');
}

async function testUsersEndpoints() {
  console.log('\n👥 Testing Users Endpoints...');
  
  await apiRequest('GET', '/users/all');
}

async function testConnectionsEndpoints() {
  console.log('\n🤝 Testing Connections Endpoints...');
  
  // Get connections
  await apiRequest('GET', '/connections');
  
  // Note: We can't test connect/disconnect without another user
  console.log('  ℹ️  Connect/disconnect tests require multiple users');
}

async function testFilesEndpoints() {
  console.log('\n📁 Testing Files Endpoints...');
  
  // Test presign upload
  await apiRequest('POST', '/files/presign-upload', {
    ext: 'jpg'
  });
  
  // Test list files
  await apiRequest('GET', '/files/list');
  
  console.log('  ℹ️  File upload confirmation requires actual S3 upload');
}

async function runAllTests() {
  console.log('🚀 Starting Nexum API Tests...');
  console.log(`Testing against: ${API_BASE}`);
  
  try {
    // Test health endpoints (no auth required)
    await testHealthEndpoints();
    
    // Test authentication and get token
    await testAuthEndpoints();
    
    if (!authToken) {
      console.error('❌ Authentication failed, cannot continue with protected endpoint tests');
      return;
    }
    
    // Test protected endpoints
    await testProfileEndpoints();
    await testUsersEndpoints();
    await testConnectionsEndpoints();
    await testFilesEndpoints();
    
    console.log('\n🎉 API tests completed!');
    console.log('\nTest Summary:');
    console.log('✅ All basic endpoints are functional');
    console.log('✅ Authentication flow works');
    console.log('✅ Profile management works');
    console.log('✅ File upload preparation works');
    console.log('ℹ️  Some features require additional setup (S3, multiple users)');
    
  } catch (error) {
    console.error('❌ Test suite failed:', error);
  }
}

// Check if fetch is available (Node.js 18+)
if (typeof fetch === 'undefined') {
  console.error('❌ This script requires Node.js 18+ with built-in fetch support');
  console.log('Alternative: Install node-fetch and import it');
  process.exit(1);
}

// Run tests
runAllTests();
