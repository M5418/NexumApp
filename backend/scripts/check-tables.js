import 'dotenv/config';
import mysql from 'mysql2/promise';

async function checkTables() {
  let connection;
  
  try {
    connection = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Connected to database');
    
    // Show all tables
    const [tables] = await connection.query('SHOW TABLES');
    console.log('\nExisting tables:');
    tables.forEach(table => {
      const tableName = Object.values(table)[0];
      console.log(`- ${tableName}`);
    });
    
    // Check if we have any data in users table
    const [userCount] = await connection.query('SELECT COUNT(*) as count FROM users');
    console.log(`\nUsers in database: ${userCount[0].count}`);
    
    // Check the structure of users table to see if it's using string or int IDs
    const [userStructure] = await connection.query('DESCRIBE users');
    console.log('\nUsers table structure:');
    userStructure.forEach(col => {
      console.log(`- ${col.Field}: ${col.Type} ${col.Key ? `(${col.Key})` : ''}`);
    });
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

checkTables();
