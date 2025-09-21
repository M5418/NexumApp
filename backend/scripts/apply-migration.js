import 'dotenv/config';
import fs from 'fs';
import path from 'path';
import mysql from 'mysql2/promise';

async function main() {
  const fileArg = process.argv[2];
  if (!fileArg) {
    console.error('Usage: node scripts/apply-migration.js <filename.sql>');
    process.exit(1);
  }

  const sqlPath = path.join(process.cwd(), 'src', 'db', 'migrations', fileArg);
  if (!fs.existsSync(sqlPath)) {
    console.error(`❌ File not found: ${sqlPath}`);
    process.exit(1);
  }

  let conn;
  try {
    const sql = fs.readFileSync(sqlPath, 'utf8');
    conn = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Connected to database');
    console.log(`Applying migration: ${fileArg}`);

    const statements = sql
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    for (const stmt of statements) {
      try {
        await conn.query(stmt);
      } catch (err) {
        if (err && (String(err.message).includes('already exists') || err.code === 'ER_DUP_KEYNAME' || err.code === 'ER_DUP_ENTRY')) {
          console.log(`  ⚠️  Skipped: ${err.message}`);
          continue;
        }
        throw err;
      }
    }

    console.log('✅ Migration applied successfully');
  } catch (e) {
    console.error('❌ Failed to apply migration:', e.message || e);
    process.exit(1);
  } finally {
    if (conn) await conn.end();
  }
}

main();
