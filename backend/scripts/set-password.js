import 'dotenv/config';
import mysql from 'mysql2/promise';
import bcrypt from 'bcrypt';
import { generateUserId } from '../src/utils/id-generator.js';

async function main() {
  const [email, newPassword] = process.argv.slice(2);
  if (!email || !newPassword) {
    console.error('Usage: node scripts/set-password.js <email> <newPassword>');
    process.exit(1);
  }

  let conn;
  try {
    conn = await mysql.createConnection(process.env.DATABASE_URL);
    const [dbRow] = await conn.query('SELECT DATABASE() db');
    console.log('Connected DB:', dbRow[0].db);

    // Check if user exists
    const [rows] = await conn.query('SELECT id FROM users WHERE email = ?', [email]);
    const hash = await bcrypt.hash(newPassword, 12);

    if (rows.length === 0) {
      const id = generateUserId();
      await conn.query(
        'INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)',
        [id, email, hash]
      );
      console.log(`✅ Created user ${email} with new password`);
    } else {
      await conn.query('UPDATE users SET password_hash = ? WHERE email = ?', [hash, email]);
      console.log(`✅ Updated password for ${email}`);
    }

    console.log('Done');
  } catch (e) {
    console.error('❌ Failed:', e.message || e);
    process.exit(1);
  } finally {
    if (conn) await conn.end();
  }
}

main();
