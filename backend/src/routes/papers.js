import express from 'express';
import { 
  createPaper,
  getPapers,
  getPaper,
  updatePaper,
  deletePaper,
  downloadPaper
} from '../controllers/papersController.js';
import { authenticateToken } from '../middleware/auth.js';
import { uploadPDF } from '../middleware/upload.js';

const router = express.Router();

router.use(authenticateToken);

router.post('/', uploadPDF.single('file'), createPaper);
router.get('/', getPapers);
router.get('/:id', getPaper);
router.put('/:id', updatePaper);
router.delete('/:id', deletePaper);
router.get('/:id/download', downloadPaper);

export default router;