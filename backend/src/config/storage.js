import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs/promises';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const STORAGE_CONFIG = {
  PDF_STORAGE_PATH: path.join(__dirname, '../../../storage/pdfs'),
  MAX_FILE_SIZE: 50 * 1024 * 1024, // 50MB
  ALLOWED_MIME_TYPES: ['application/pdf'],
  ALLOWED_EXTENSIONS: ['.pdf']
};

export async function ensureStorageDirectories() {
  try {
    await fs.access(STORAGE_CONFIG.PDF_STORAGE_PATH);
  } catch (error) {
    await fs.mkdir(STORAGE_CONFIG.PDF_STORAGE_PATH, { recursive: true });
  }
}

export function generateFileName(originalName, userId) {
  const timestamp = Date.now();
  const extension = path.extname(originalName);
  const baseName = path.basename(originalName, extension)
    .replace(/[^a-zA-Z0-9]/g, '_')
    .substring(0, 50);
  
  return `${userId}_${timestamp}_${baseName}${extension}`;
}

export function getFilePath(filename) {
  return path.join(STORAGE_CONFIG.PDF_STORAGE_PATH, filename);
}