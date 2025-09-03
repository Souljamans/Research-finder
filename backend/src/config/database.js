import pkg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const { Pool } = pkg;

export const pool = new Pool({
  user: process.env.DB_USER || 'research_user',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'research_papers',
  password: process.env.DB_PASSWORD || 'research_pass',
  port: process.env.DB_PORT || 5432,
});

export async function testConnection() {
  try {
    const client = await pool.connect();
    await client.query('SELECT NOW()');
    client.release();
    console.log('Database connected successfully');
    return true;
  } catch (error) {
    console.error('Database connection failed:', error.message);
    return false;
  }
}