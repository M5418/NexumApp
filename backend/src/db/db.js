import mysql from 'mysql2/promise';

// Use a standard MySQL connection URL, e.g. mysql://user:pass@host:3306/db
const pool = mysql.createPool(process.env.DATABASE_URL);

export default pool;
