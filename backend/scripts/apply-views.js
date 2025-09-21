import 'dotenv/config';
import fs from 'fs';
import path from 'path';
import mysql from 'mysql2/promise';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function applyViews() {
  let connection;
  try {
    const sqlPath = path.join(__dirname, '..', 'src', 'db', 'migrations', '006_user_connections_view.sql');
    if (!fs.existsSync(sqlPath)) {
      console.error('❌ View migration file not found at', sqlPath);
      process.exit(1);
    }

    const sql = fs.readFileSync(sqlPath, 'utf8');

    connection = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Connected to database');

    console.log('Applying views from 006_user_connections_view.sql ...');

    // Split and run statements one by one
    const statements = sql
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    for (const stmt of statements) {
      try {
        await connection.query(stmt);
      } catch (err) {
        // If view exists or other benign issues, continue
        if (err.message && (err.message.includes('already exists') || err.code === 'ER_SP_DOES_NOT_EXIST')) {
          console.log(`  ⚠️  Skipped: ${err.message}`);
          continue;
        }
        throw err;
      }
    }

    console.log('✅ Views applied successfully');
    console.log('\nTry querying:');
    console.log("SELECT * FROM v_user_connections WHERE user_id = 'YourUserID';");
    console.log("SELECT * FROM v_user_connections_detailed WHERE user_id = 'YourUserID';");
  } catch (error) {
    console.error('❌ Failed to apply views:', error.message || error);
    process.exit(1);
  } finally {
    if (connection) await connection.end();
  }
}

applyViews();
