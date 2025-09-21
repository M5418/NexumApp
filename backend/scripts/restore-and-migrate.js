import 'dotenv/config';
import mysql from 'mysql2/promise';
import { generateUserId } from '../src/utils/id-generator.js';

async function restoreAndMigrate() {
  let connection;
  
  try {
    connection = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Connected to database');
    
    // Step 1: Check what backup tables exist
    const [tables] = await connection.query("SHOW TABLES LIKE '%_backup'");
    console.log('Found backup tables:', tables.map(t => Object.values(t)[0]));
    
    // Step 2: Drop existing tables and recreate with string IDs
    console.log('\n🗑️  Dropping existing tables...');
    
    // Drop in correct order (foreign keys first)
    try {
      await connection.query('DROP TABLE IF EXISTS connections');
      await connection.query('DROP TABLE IF EXISTS uploads');
      await connection.query('DROP TABLE IF EXISTS profiles');
      await connection.query('DROP TABLE IF EXISTS users');
      console.log('✅ Dropped existing tables');
    } catch (error) {
      console.log('ℹ️  Some tables may not have existed');
    }
    
    console.log('\n📋 Creating tables with string IDs...');
    
    // Create users table
    await connection.query(`
      CREATE TABLE users (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        email VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✅ Created users table');
    
    // Create profiles table
    await connection.query(`
      CREATE TABLE profiles (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        user_id VARCHAR(12) NOT NULL UNIQUE,
        first_name VARCHAR(100) NULL,
        last_name VARCHAR(100) NULL,
        username VARCHAR(100) NULL UNIQUE,
        birthday DATE NULL,
        gender VARCHAR(50) NULL,
        status VARCHAR(50) NULL,
        interest_domains JSON NULL,
        street VARCHAR(255) NULL,
        city VARCHAR(100) NULL,
        state VARCHAR(100) NULL,
        postal_code VARCHAR(20) NULL,
        country VARCHAR(100) NULL,
        profile_photo_url TEXT NULL,
        cover_photo_url TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        professional_experiences JSON NULL,
        trainings JSON NULL,
        bio TEXT NULL,
        CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) REFERENCES users (id)
      )
    `);
    console.log('✅ Created profiles table');
    
    // Create uploads table
    await connection.query(`
      CREATE TABLE uploads (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        user_id VARCHAR(12) NULL,
        s3_key VARCHAR(512) NOT NULL,
        url TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT uploads_ibfk_1 FOREIGN KEY (user_id) REFERENCES users (id),
        INDEX user_id (user_id)
      )
    `);
    console.log('✅ Created uploads table');
    
    // Create connections table
    await connection.query(`
      CREATE TABLE connections (
        from_user_id VARCHAR(12) NOT NULL,
        to_user_id VARCHAR(12) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (from_user_id, to_user_id),
        CONSTRAINT connections_ibfk_1 FOREIGN KEY (from_user_id) REFERENCES users (id) ON DELETE CASCADE,
        CONSTRAINT connections_ibfk_2 FOREIGN KEY (to_user_id) REFERENCES users (id) ON DELETE CASCADE,
        INDEX to_user_id (to_user_id)
      )
    `);
    console.log('✅ Created connections table');
    
    // Step 3: Check backup table structure
    console.log('\n🔍 Checking backup table structure...');
    const [profilesBackupStructure] = await connection.query('DESCRIBE profiles_backup');
    console.log('Profiles backup columns:', profilesBackupStructure.map(col => col.Field));
    
    // Step 4: Check if we have backup data to migrate
    const [backupUsers] = await connection.query('SELECT COUNT(*) as count FROM profiles_backup');
    console.log(`\n📊 Found ${backupUsers[0].count} profiles in backup to migrate`);
    
    if (backupUsers[0].count === 0) {
      console.log('No data to migrate. Tables are ready for new data with string IDs.');
      return;
    }
    
    // Step 5: Migrate data from backup tables
    console.log('\n🔄 Starting data migration...');
    
    // Get backup data with proper column selection
    let backupProfiles;
    try {
      const [usersBackupCheck] = await connection.query("SHOW TABLES LIKE 'users_backup'");
      if (usersBackupCheck.length > 0) {
        // Get users and profiles with JOIN
        [backupProfiles] = await connection.query(`
          SELECT 
            p.user_id, 
            u.email, 
            u.password_hash, 
            u.created_at as user_created_at,
            p.id as profile_id,
            p.first_name,
            p.last_name,
            p.username,
            p.birthday,
            p.gender,
            p.status,
            p.interest_domains,
            p.street,
            p.city,
            p.state,
            p.postal_code,
            p.country,
            p.profile_photo_url,
            p.cover_photo_url,
            p.created_at as profile_created_at,
            p.updated_at as profile_updated_at,
            p.professional_experiences,
            p.trainings,
            p.bio
          FROM profiles_backup p
          LEFT JOIN users_backup u ON u.id = p.user_id
          ORDER BY p.user_id
        `);
      } else {
        // Just get profiles, we'll need to create users from profile data
        [backupProfiles] = await connection.query(`
          SELECT 
            user_id,
            id as profile_id,
            first_name,
            last_name,
            username,
            birthday,
            gender,
            status,
            interest_domains,
            street,
            city,
            state,
            postal_code,
            country,
            profile_photo_url,
            cover_photo_url,
            created_at as profile_created_at,
            updated_at as profile_updated_at,
            professional_experiences,
            trainings,
            bio
          FROM profiles_backup 
          ORDER BY user_id
        `);
      }
    } catch (error) {
      console.log('Error getting backup data:', error.message);
      return;
    }
    
    console.log(`Found ${backupProfiles.length} user profiles to migrate`);
    
    // Create ID mapping
    const userIdMap = new Map();
    
    // Migrate users and profiles
    for (const profile of backupProfiles) {
      const newUserId = generateUserId();
      const newProfileId = generateUserId();
      
      userIdMap.set(profile.user_id.toString(), newUserId);
      
      // Insert user (create a basic user if we don't have user data)
      const email = profile.email || `user${profile.user_id}@nexum.app`;
      const passwordHash = profile.password_hash || 'temp_hash_needs_reset';
      const userCreatedAt = profile.user_created_at || profile.profile_created_at || new Date();
      
      await connection.query(
        'INSERT INTO users (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)',
        [newUserId, email, passwordHash, userCreatedAt]
      );
      
      // Insert profile with explicit column mapping
      await connection.query(
        `INSERT INTO profiles (
          id, user_id, first_name, last_name, username, birthday, gender,
          status, interest_domains, street, city, state, postal_code, country,
          profile_photo_url, cover_photo_url, created_at, updated_at,
          professional_experiences, trainings, bio
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          newProfileId, 
          newUserId, 
          profile.first_name, 
          profile.last_name,
          profile.username, 
          profile.birthday, 
          profile.gender, 
          profile.status,
          profile.interest_domains, 
          profile.street, 
          profile.city, 
          profile.state,
          profile.postal_code, 
          profile.country, 
          profile.profile_photo_url,
          profile.cover_photo_url, 
          profile.profile_created_at, 
          profile.profile_updated_at,
          profile.professional_experiences, 
          profile.trainings, 
          profile.bio
        ]
      );
    }
    
    console.log('✅ Migrated users and profiles');
    
    // Migrate uploads if they exist
    try {
      const [backupUploads] = await connection.query('SELECT * FROM uploads_backup');
      console.log(`Migrating ${backupUploads.length} uploads...`);
      
      for (const upload of backupUploads) {
        const newUploadId = generateUserId();
        const newUserId = upload.user_id ? userIdMap.get(upload.user_id.toString()) : null;
        
        await connection.query(
          'INSERT INTO uploads (id, user_id, s3_key, url, created_at) VALUES (?, ?, ?, ?, ?)',
          [newUploadId, newUserId, upload.s3_key, upload.url, upload.created_at]
        );
      }
      console.log('✅ Migrated uploads');
    } catch (error) {
      console.log('ℹ️  No uploads to migrate');
    }
    
    // Migrate connections if they exist
    try {
      const [backupConnections] = await connection.query('SELECT * FROM connections_backup');
      console.log(`Migrating ${backupConnections.length} connections...`);
      
      for (const conn of backupConnections) {
        const newFromUserId = userIdMap.get(conn.from_user_id.toString());
        const newToUserId = userIdMap.get(conn.to_user_id.toString());
        
        if (newFromUserId && newToUserId) {
          await connection.query(
            'INSERT INTO connections (from_user_id, to_user_id, created_at) VALUES (?, ?, ?)',
            [newFromUserId, newToUserId, conn.created_at]
          );
        }
      }
      console.log('✅ Migrated connections');
    } catch (error) {
      console.log('ℹ️  No connections to migrate');
    }
    
    // Step 6: Show final summary
    const [finalUserCount] = await connection.query('SELECT COUNT(*) as count FROM users');
    const [finalProfileCount] = await connection.query('SELECT COUNT(*) as count FROM profiles');
    
    console.log('\n🎉 Migration completed successfully!');
    console.log(`\nFinal counts:`);
    console.log(`- Users: ${finalUserCount[0].count}`);
    console.log(`- Profiles: ${finalProfileCount[0].count}`);
    
    console.log('\n📝 Next steps:');
    console.log('1. Generate Prisma client: npm run prisma:generate');
    console.log('2. Test the API: npm run test');
    console.log('3. Check Prisma Studio: npm run prisma:studio');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

restoreAndMigrate();
