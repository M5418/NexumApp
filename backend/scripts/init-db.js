import 'dotenv/config';
import mysql from 'mysql2/promise';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function initializeDatabase() {
  let connection;
  
  try {
    // Parse DATABASE_URL to get connection details
    const dbUrl = new URL(process.env.DATABASE_URL);
    const dbName = dbUrl.pathname.slice(1); // Remove leading slash
    
    // Connect without database name first
    const connectionConfig = {
      host: dbUrl.hostname,
      port: dbUrl.port || 3306,
      user: dbUrl.username,
      password: dbUrl.password,
      multipleStatements: true  // Enable multiple statements
    };
    
    connection = await mysql.createConnection(connectionConfig);
    
    console.log('Connected to MySQL server');
    
    // Create database if it doesn't exist
    await connection.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\``);
    console.log(`Database '${dbName}' created or already exists`);
    
    // Use the database
    await connection.query(`USE \`${dbName}\``);
    console.log(`Using database '${dbName}'`);
    
    // Read and execute migration files in order
    const migrationsDir = path.join(__dirname, '..', 'src', 'db', 'migrations');
    
    if (!fs.existsSync(migrationsDir)) {
      console.log('No migrations directory found, skipping migrations');
      return;
    }
    
    const migrationFiles = fs.readdirSync(migrationsDir)
      .filter(file => file.endsWith('.sql'))
      .sort();
    
    if (migrationFiles.length === 0) {
      console.log('No migration files found');
      return;
    }
    
    for (const file of migrationFiles) {
      const filePath = path.join(migrationsDir, file);
      const sql = fs.readFileSync(filePath, 'utf8');
      
      console.log(`Executing migration: ${file}`);
      
      // Split by semicolon and execute each statement separately
      const statements = sql
        .split(';')
        .map(stmt => stmt.trim())
        .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));
      
      for (const statement of statements) {
        if (statement.trim()) {
          try {
            // Use query() instead of execute() for DDL statements
            await connection.query(statement);
          } catch (error) {
            // Skip errors for statements that might already exist
            if (error.code === 'ER_TABLE_EXISTS_ERROR' || 
                error.code === 'ER_DUP_KEYNAME' ||
                error.code === 'ER_DUP_ENTRY' ||
                error.code === 'ER_DUP_FIELDNAME' ||
                error.message.includes('already exists') ||
                error.message.includes('Duplicate') ||
                error.message.includes('duplicate column name')) {
              console.log(`  ⚠️  Skipped: ${error.message}`);
              continue;
            }
            throw error;
          }
        }
      }
      
      console.log(`✅ Executed migration: ${file}`);
    }
    
    console.log('\n🎉 Database initialization completed successfully!');
    console.log('\nNext steps:');
    console.log('1. Generate Prisma client: npm run prisma:generate');
    console.log('2. Start the server: npm run dev');
    console.log('3. Test the API: npm run test');
    console.log('4. Check Prisma Studio: npm run prisma:studio');
    
  } catch (error) {
    console.error('❌ Database initialization failed:', error.message);
    console.log('\nTroubleshooting:');
    console.log('1. Check your DATABASE_URL in .env file');
    console.log('2. Ensure MySQL server is running');
    console.log('3. Verify database credentials');
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run the initialization
initializeDatabase();
