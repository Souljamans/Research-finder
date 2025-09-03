import multer from 'multer';
import path from 'path';
import { STORAGE_CONFIG, generateFileName } from '../config/storage.js';

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, STORAGE_CONFIG.PDF_STORAGE_PATH);
  },
  filename: function (req, file, cb) {
    const userId = req.user?.id || 'anonymous';
    const filename = generateFileName(file.originalname, userId);
    cb(null, filename);
  }
});

const fileFilter = (req, file, cb) => {
  if (STORAGE_CONFIG.ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    const ext = path.extname(file.originalname).toLowerCase();
    if (STORAGE_CONFIG.ALLOWED_EXTENSIONS.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only PDF files are allowed'), false);
    }
  } else {
    cb(new Error('Only PDF files are allowed'), false);
  }
};

export const uploadPDF = multer({
  storage: storage,
  limits: {
    fileSize: STORAGE_CONFIG.MAX_FILE_SIZE
  },
  fileFilter: fileFilter
});