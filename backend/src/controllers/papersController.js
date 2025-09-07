import { Paper } from '../models/Paper.js';
import { Note } from '../models/Note.js';
import path from 'path';
import fs from 'fs/promises';
import { getFilePath } from '../config/storage.js';
import { PDFService } from '../services/pdfService.js';

export async function createPaper(req, res) {
  try {
    const { title, authors, abstract, keywords, metadata } = req.body;
    const userId = req.user.id;

    let paperTitle = title;
    let paperAuthors = Array.isArray(authors) ? authors : (authors ? [authors] : []);
    let paperAbstract = abstract || '';
    let extractedText = null;
    let pdfMetadata = null;
    let processingStatus = { status: 'none' };

    if (req.file) {
      try {
        processingStatus.status = 'processing';
        processingStatus.steps = ['Extracting text...', 'Extracting metadata...', 'Processing complete'];
        
        const processedData = await PDFService.processUploadedPDF(req.file.filename);
        extractedText = processedData.extractedText;
        pdfMetadata = processedData.metadata;

        if (!paperTitle && pdfMetadata.extractedTitle) {
          paperTitle = pdfMetadata.extractedTitle;
        }
        if (!paperTitle && pdfMetadata.title) {
          paperTitle = pdfMetadata.title;
        }
        
        if (paperAuthors.length === 0 && pdfMetadata.extractedAuthors?.length > 0) {
          paperAuthors = pdfMetadata.extractedAuthors;
        }
        if (paperAuthors.length === 0 && pdfMetadata.author) {
          paperAuthors = [pdfMetadata.author];
        }

        processingStatus.status = 'completed';
        
      } catch (pdfError) {
        console.warn('PDF processing failed:', pdfError.message);
        processingStatus.status = 'failed';
        processingStatus.error = pdfError.message;
      }
    }

    if (!paperTitle) {
      return res.status(400).json({ error: 'Title is required' });
    }

    const paperData = {
      title: paperTitle,
      authors: paperAuthors,
      abstract: paperAbstract,
      keywords: Array.isArray(keywords) ? keywords : (keywords ? [keywords] : []),
      user_id: userId,
      metadata: {
        ...metadata,
        ...pdfMetadata,
        extractedText,
        processingInfo: {
          processedAt: new Date().toISOString(),
          textExtracted: !!extractedText,
          metadataExtracted: !!pdfMetadata,
          wordCount: pdfMetadata?.wordCount || 0
        }
      }
    };

    if (req.file) {
      paperData.file_path = req.file.filename;
      paperData.file_size = req.file.size;
    }

    const paper = await Paper.create(paperData);

    res.status(201).json({
      message: 'Paper created successfully',
      paper: paper.toJSON(),
      processing: processingStatus
    });
    
  } catch (error) {
    console.error('Create paper error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function getPapers(req, res) {
  try {
    const userId = req.user.id;
    const {
      page = 1,
      limit = 20,
      search = '',
      sortBy = 'created_at',
      sortOrder = 'DESC'
    } = req.query;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const options = {
      limit: parseInt(limit),
      offset,
      search,
      sortBy,
      sortOrder
    };

    const [papers, total] = await Promise.all([
      Paper.findByUserId(userId, options),
      Paper.count(userId, search)
    ]);

    res.json({
      papers: papers.map(paper => paper.toJSON()),
      pagination: {
        current_page: parseInt(page),
        total_pages: Math.ceil(total / parseInt(limit)),
        total_count: total,
        per_page: parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Get papers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function getPaper(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const paper = await Paper.findById(id, userId);
    
    if (!paper) {
      return res.status(404).json({ error: 'Paper not found' });
    }

    const notes = await Note.findByPaperId(id, userId);

    res.json({
      paper: paper.toJSON(),
      notes: notes.map(note => note.toJSON())
    });
  } catch (error) {
    console.error('Get paper error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function updatePaper(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const updateData = req.body;

    if (updateData.authors && !Array.isArray(updateData.authors)) {
      updateData.authors = updateData.authors ? [updateData.authors] : [];
    }

    if (updateData.keywords && !Array.isArray(updateData.keywords)) {
      updateData.keywords = updateData.keywords ? [updateData.keywords] : [];
    }

    const paper = await Paper.update(id, userId, updateData);
    
    if (!paper) {
      return res.status(404).json({ error: 'Paper not found' });
    }

    res.json({
      message: 'Paper updated successfully',
      paper: paper.toJSON()
    });
  } catch (error) {
    console.error('Update paper error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function deletePaper(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const paper = await Paper.findById(id, userId);
    if (!paper) {
      return res.status(404).json({ error: 'Paper not found' });
    }

    await Note.deleteByPaperId(id, userId);

    const deleted = await Paper.delete(id, userId);
    
    if (!deleted) {
      return res.status(404).json({ error: 'Paper not found' });
    }

    if (paper.file_path) {
      try {
        const filePath = getFilePath(paper.file_path);
        await fs.unlink(filePath);
      } catch (fileError) {
        console.warn('Could not delete file:', fileError.message);
      }
    }

    res.json({ message: 'Paper deleted successfully' });
  } catch (error) {
    console.error('Delete paper error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function downloadPaper(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const paper = await Paper.findById(id, userId);
    
    if (!paper || !paper.file_path) {
      return res.status(404).json({ error: 'Paper file not found' });
    }

    const filePath = getFilePath(paper.file_path);
    
    try {
      await fs.access(filePath);
    } catch (error) {
      return res.status(404).json({ error: 'File not found on server' });
    }

    const fileName = `${paper.title.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`;
    
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
    
    res.sendFile(path.resolve(filePath));
  } catch (error) {
    console.error('Download paper error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function reprocessPaper(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const paper = await Paper.findById(id, userId);
    
    if (!paper) {
      return res.status(404).json({ error: 'Paper not found' });
    }

    if (!paper.file_path) {
      return res.status(400).json({ error: 'No PDF file associated with this paper' });
    }

    let processingStatus = { status: 'processing', steps: ['Re-extracting text...', 'Re-extracting metadata...', 'Updating paper...'] };
    
    try {
      const processedData = await PDFService.processUploadedPDF(paper.file_path);
      
      const updateData = {
        metadata: {
          ...paper.metadata,
          ...processedData.metadata,
          extractedText: processedData.extractedText,
          processingInfo: {
            processedAt: new Date().toISOString(),
            textExtracted: !!processedData.extractedText,
            metadataExtracted: !!processedData.metadata,
            wordCount: processedData.metadata?.wordCount || 0,
            reprocessed: true
          }
        }
      };

      if (processedData.metadata.extractedTitle && !req.body.keepTitle) {
        updateData.title = processedData.metadata.extractedTitle;
      }

      if (processedData.metadata.extractedAuthors?.length > 0 && !req.body.keepAuthors) {
        updateData.authors = processedData.metadata.extractedAuthors;
      }

      const updatedPaper = await Paper.update(id, userId, updateData);
      
      processingStatus.status = 'completed';

      res.json({
        message: 'Paper reprocessed successfully',
        paper: updatedPaper.toJSON(),
        processing: processingStatus
      });

    } catch (pdfError) {
      console.error('PDF reprocessing failed:', pdfError.message);
      res.status(500).json({ 
        error: 'Failed to reprocess PDF',
        details: pdfError.message,
        processing: { status: 'failed', error: pdfError.message }
      });
    }

  } catch (error) {
    console.error('Reprocess paper error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}