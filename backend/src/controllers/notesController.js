import { Note } from '../models/Note.js';
import { Paper } from '../models/Paper.js';

export async function createNote(req, res) {
  try {
    const { paper_id, content, page_number, position_x, position_y } = req.body;
    const userId = req.user.id;

    if (!paper_id || !content) {
      return res.status(400).json({ error: 'Paper ID and content are required' });
    }

    const paper = await Paper.findById(paper_id, userId);
    if (!paper) {
      return res.status(404).json({ error: 'Paper not found' });
    }

    const noteData = {
      paper_id,
      user_id: userId,
      content,
      page_number: page_number || null,
      position_x: position_x || null,
      position_y: position_y || null
    };

    const note = await Note.create(noteData);

    res.status(201).json({
      message: 'Note created successfully',
      note: note.toJSON()
    });
  } catch (error) {
    console.error('Create note error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function getNotes(req, res) {
  try {
    const userId = req.user.id;
    const {
      page = 1,
      limit = 50,
      search = '',
      paper_id,
      page_number
    } = req.query;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const options = {
      limit: parseInt(limit),
      offset,
      search,
      page_number: page_number ? parseInt(page_number) : null
    };

    let notes, total;

    if (paper_id) {
      const paper = await Paper.findById(paper_id, userId);
      if (!paper) {
        return res.status(404).json({ error: 'Paper not found' });
      }

      [notes, total] = await Promise.all([
        Note.findByPaperId(paper_id, userId, options),
        Note.count(userId, paper_id, search)
      ]);
    } else {
      [notes, total] = await Promise.all([
        Note.findByUserId(userId, options),
        Note.count(userId, null, search)
      ]);
    }

    res.json({
      notes: notes.map(note => note.toJSON()),
      pagination: {
        current_page: parseInt(page),
        total_pages: Math.ceil(total / parseInt(limit)),
        total_count: total,
        per_page: parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Get notes error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function getNote(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const note = await Note.findById(id, userId);
    
    if (!note) {
      return res.status(404).json({ error: 'Note not found' });
    }

    res.json({
      note: note.toJSON()
    });
  } catch (error) {
    console.error('Get note error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function updateNote(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const updateData = req.body;

    const note = await Note.update(id, userId, updateData);
    
    if (!note) {
      return res.status(404).json({ error: 'Note not found' });
    }

    res.json({
      message: 'Note updated successfully',
      note: note.toJSON()
    });
  } catch (error) {
    console.error('Update note error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function deleteNote(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const deleted = await Note.delete(id, userId);
    
    if (!deleted) {
      return res.status(404).json({ error: 'Note not found' });
    }

    res.json({ message: 'Note deleted successfully' });
  } catch (error) {
    console.error('Delete note error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export async function getNotesWithPapers(req, res) {
  try {
    const userId = req.user.id;
    const {
      page = 1,
      limit = 50,
      search = ''
    } = req.query;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const options = {
      limit: parseInt(limit),
      offset,
      search
    };

    const [notes, total] = await Promise.all([
      Note.getNotesWithPaperInfo(userId, options),
      Note.count(userId, null, search)
    ]);

    res.json({
      notes,
      pagination: {
        current_page: parseInt(page),
        total_pages: Math.ceil(total / parseInt(limit)),
        total_count: total,
        per_page: parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Get notes with papers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}