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
    const rawUrl = process.env.DATABASE_URL;
    if (!rawUrl || !rawUrl.startsWith('mysql://')) {
      throw new Error(`Invalid or missing DATABASE_URL (got: ${rawUrl || 'undefined'})`);
    }

    const dbUrl = new URL(rawUrl);
    const dbName = dbUrl.pathname.slice(1);
    if (!dbName) throw new Error('DATABASE_URL is missing a database name');

    const connectionConfig = {
      host: dbUrl.hostname,
      port: Number(dbUrl.port || 3306),
      user: decodeURIComponent(dbUrl.username),
      password: decodeURIComponent(dbUrl.password),
      database: dbName,              // connect directly to the DB
      multipleStatements: true,
    };

    connection = await mysql.createConnection(connectionConfig);
    console.log(`Connected to MySQL server and database '${dbName}'`);

    const migrationsDir = path.join(__dirname, '..', 'src', 'db', 'migrations');
    if (!fs.existsSync(migrationsDir)) {
      console.log('No migrations directory found, skipping migrations');
      return;
    }

    const migrationFiles = fs.readdirSync(migrationsDir)
      .filter((file) => file.endsWith('.sql'))
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
        .map((stmt) => stmt.trim())
        .filter((stmt) => stmt.length > 0 && !stmt.startsWith('--'));

      for (const statement of statements) {
        try {
          await connection.query(statement);
        } catch (error) {
          // Skip expected duplicates
          const msg = String(error?.message || '');
          if (
            error.code === 'ER_TABLE_EXISTS_ERROR' ||
            error.code === 'ER_DUP_KEYNAME' ||
            error.code === 'ER_DUP_ENTRY' ||
            error.code === 'ER_DUP_FIELDNAME' ||
            msg.includes('already exists') ||
            msg.includes('Duplicate') ||
            msg.includes('duplicate column name')
          ) {
            console.log(`  ⚠️  Skipped: ${msg}`);
            continue;
          }
          throw error;
        }
      }

      console.log(`✅ Executed migration: ${file}`);
    }

    console.log('\n🎉 Database initialization completed successfully!');
  } catch (error) {
    console.error('❌ Database initialization failed:', error?.message || error);
    console.log('\nTroubleshooting:');
    console.log('1. Check your DATABASE_URL in .env file');
    console.log('2. Ensure MySQL server is running and reachable');
    console.log('3. Verify database/user credentials and port');
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run the initialization
initializeDatabase();