import 'dotenv/config';
import mysql from 'mysql2/promise';
import { generateUserId } from '../src/utils/id-generator.js';

async function migrateToStringIds() {
  let connection;
  
  try {
    // Connect to database
    connection = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Connected to database');
    
    // Step 1: Check if backup tables exist (migration already run)
    const [backupCheck] = await connection.execute(
      "SHOW TABLES LIKE 'users_backup'"
    );
    
    if (backupCheck.length === 0) {
      console.log('❌ No backup tables found. Please run the SQL migration first.');
      console.log('Run: npm run db:init');
      return;
    }
    
    console.log('📋 Found backup tables, starting data migration...');
    
    // Step 2: Get all users from backup
    const [backupUsers] = await connection.execute(
      'SELECT * FROM users_backup ORDER BY id'
    );
    
    console.log(`Found ${backupUsers.length} users to migrate`);
    
    // Step 3: Create ID mapping for users
    const userIdMap = new Map();
    
    for (const user of backupUsers) {
      const newId = generateUserId();
      userIdMap.set(user.id.toString(), newId);
      
      // Insert user with new string ID
      await connection.execute(
        'INSERT INTO users (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)',
        [newId, user.email, user.password_hash, user.created_at]
      );
    }
    
    console.log('✅ Migrated users with new string IDs');
    
    // Step 4: Migrate profiles
    const [backupProfiles] = await connection.execute(
      'SELECT * FROM profiles_backup ORDER BY id'
    );
    
    console.log(`Found ${backupProfiles.length} profiles to migrate`);
    
    for (const profile of backupProfiles) {
      const newProfileId = generateUserId();
      const newUserId = userIdMap.get(profile.user_id.toString());
      
      if (!newUserId) {
        console.warn(`⚠️  Skipping profile ${profile.id} - user not found`);
        continue;
      }
      
      await connection.execute(
        `INSERT INTO profiles (
          id, user_id, first_name, last_name, username, birthday, gender,
          status, interest_domains, street, city, state, postal_code, country,
          profile_photo_url, cover_photo_url, created_at, updated_at,
          professional_experiences, trainings, bio
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          newProfileId, newUserId, profile.first_name, profile.last_name,
          profile.username, profile.birthday, profile.gender, profile.status,
          profile.interest_domains, profile.street, profile.city, profile.state,
          profile.postal_code, profile.country, profile.profile_photo_url,
          profile.cover_photo_url, profile.created_at, profile.updated_at,
          profile.professional_experiences, profile.trainings, profile.bio
        ]
      );
    }
    
    console.log('✅ Migrated profiles with new string IDs');
    
    // Step 5: Migrate uploads
    const [backupUploads] = await connection.execute(
      'SELECT * FROM uploads_backup ORDER BY id'
    );
    
    console.log(`Found ${backupUploads.length} uploads to migrate`);
    
    for (const upload of backupUploads) {
      const newUploadId = generateUserId();
      const newUserId = upload.user_id ? userIdMap.get(upload.user_id.toString()) : null;
      
      await connection.execute(
        'INSERT INTO uploads (id, user_id, s3_key, url, created_at) VALUES (?, ?, ?, ?, ?)',
        [newUploadId, newUserId, upload.s3_key, upload.url, upload.created_at]
      );
    }
    
    console.log('✅ Migrated uploads with new string IDs');
    
    // Step 6: Migrate connections
    const [backupConnections] = await connection.execute(
      'SELECT * FROM connections_backup ORDER BY created_at'
    );
    
    console.log(`Found ${backupConnections.length} connections to migrate`);
    
    for (const conn of backupConnections) {
      const newFromUserId = userIdMap.get(conn.from_user_id.toString());
      const newToUserId = userIdMap.get(conn.to_user_id.toString());
      
      if (!newFromUserId || !newToUserId) {
        console.warn(`⚠️  Skipping connection - user not found`);
        continue;
      }
      
      await connection.execute(
        'INSERT INTO connections (from_user_id, to_user_id, created_at) VALUES (?, ?, ?)',
        [newFromUserId, newToUserId, conn.created_at]
      );
    }
    
    console.log('✅ Migrated connections with new string IDs');
    
    // Step 7: Show summary
    const [newUserCount] = await connection.execute('SELECT COUNT(*) as count FROM users');
    const [newProfileCount] = await connection.execute('SELECT COUNT(*) as count FROM profiles');
    const [newUploadCount] = await connection.execute('SELECT COUNT(*) as count FROM uploads');
    const [newConnectionCount] = await connection.execute('SELECT COUNT(*) as count FROM connections');
    
    console.log('\n🎉 Migration completed successfully!');
    console.log('\nMigration Summary:');
    console.log(`Users: ${newUserCount[0].count}`);
    console.log(`Profiles: ${newProfileCount[0].count}`);
    console.log(`Uploads: ${newUploadCount[0].count}`);
    console.log(`Connections: ${newConnectionCount[0].count}`);
    
    console.log('\n📝 Next steps:');
    console.log('1. Test your application: npm run test');
    console.log('2. Start the server: npm run dev');
    console.log('3. Check Prisma Studio: npm run prisma:studio');
    console.log('\n💡 Backup tables are preserved for safety (users_backup, profiles_backup, etc.)');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    console.log('\n🔄 You can restore from backup tables if needed');
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run the migration
migrateToStringIds();
