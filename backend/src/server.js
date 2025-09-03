import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import authRoutes from './routes/auth.js';
import papersRoutes from './routes/papers.js';
import notesRoutes from './routes/notes.js';
import { testConnection } from './config/database.js';
import { ensureStorageDirectories } from './config/storage.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/auth', authRoutes);
app.use('/api/papers', papersRoutes);
app.use('/api/notes', notesRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'Research Paper Platform API is running' });
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

async function startServer() {
  try {
    await ensureStorageDirectories();
    console.log('Storage directories initialized');

    const dbConnected = await testConnection();
    if (!dbConnected) {
      console.warn('Database connection failed, but starting server anyway');
    }

    app.listen(PORT, () => {
      console.log(`Server running on http://localhost:${PORT}`);
      console.log(`Health check: http://localhost:${PORT}/api/health`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();