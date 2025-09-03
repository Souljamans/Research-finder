import jwt from 'jsonwebtoken';
import { pool } from '../config/database.js';

export function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', async (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid token' });
    }

    try {
      const result = await pool.query('SELECT id, username, email FROM users WHERE id = $1', [user.id]);
      if (result.rows.length === 0) {
        return res.status(403).json({ error: 'User not found' });
      }
      
      req.user = result.rows[0];
      next();
    } catch (error) {
      res.status(500).json({ error: 'Database error' });
    }
  });
}

export function generateToken(user) {
  return jwt.sign(
    { id: user.id, username: user.username },
    process.env.JWT_SECRET || 'your-secret-key',
    { expiresIn: '24h' }
  );
}