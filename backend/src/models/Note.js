import { pool } from '../config/database.js';

export class Note {
  constructor({
    id,
    paper_id,
    user_id,
    content,
    page_number,
    position_x,
    position_y,
    created_at,
    updated_at
  }) {
    this.id = id;
    this.paper_id = paper_id;
    this.user_id = user_id;
    this.content = content;
    this.page_number = page_number;
    this.position_x = position_x;
    this.position_y = position_y;
    this.created_at = created_at;
    this.updated_at = updated_at;
  }

  static async create(noteData) {
    const {
      paper_id,
      user_id,
      content,
      page_number = null,
      position_x = null,
      position_y = null
    } = noteData;

    const query = `
      INSERT INTO notes (paper_id, user_id, content, page_number, position_x, position_y)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `;

    const values = [paper_id, user_id, content, page_number, position_x, position_y];

    const result = await pool.query(query, values);
    return new Note(result.rows[0]);
  }

  static async findById(id, userId) {
    const query = 'SELECT * FROM notes WHERE id = $1 AND user_id = $2';
    const result = await pool.query(query, [id, userId]);
    
    if (result.rows.length === 0) {
      return null;
    }

    return new Note(result.rows[0]);
  }

  static async findByPaperId(paperId, userId, options = {}) {
    const { limit = 100, offset = 0, page_number = null } = options;
    
    let query = 'SELECT * FROM notes WHERE paper_id = $1 AND user_id = $2';
    const values = [paperId, userId];

    if (page_number !== null) {
      query += ' AND page_number = $3';
      values.push(page_number);
    }

    query += ` ORDER BY created_at ASC LIMIT $${values.length + 1} OFFSET $${values.length + 2}`;
    values.push(limit, offset);

    const result = await pool.query(query, values);
    return result.rows.map(row => new Note(row));
  }

  static async findByUserId(userId, options = {}) {
    const { limit = 50, offset = 0, search = '' } = options;
    
    let query = 'SELECT * FROM notes WHERE user_id = $1';
    const values = [userId];

    if (search) {
      query += ` AND to_tsvector('english', content) @@ plainto_tsquery('english', $${values.length + 1})`;
      values.push(search);
    }

    query += ` ORDER BY created_at DESC LIMIT $${values.length + 1} OFFSET $${values.length + 2}`;
    values.push(limit, offset);

    const result = await pool.query(query, values);
    return result.rows.map(row => new Note(row));
  }

  static async update(id, userId, updateData) {
    const allowedFields = ['content', 'page_number', 'position_x', 'position_y'];
    const updates = [];
    const values = [];
    let valueIndex = 1;

    Object.keys(updateData).forEach(key => {
      if (allowedFields.includes(key)) {
        updates.push(`${key} = $${valueIndex}`);
        values.push(updateData[key]);
        valueIndex++;
      }
    });

    if (updates.length === 0) {
      throw new Error('No valid fields to update');
    }

    updates.push(`updated_at = CURRENT_TIMESTAMP`);
    values.push(id, userId);

    const query = `
      UPDATE notes 
      SET ${updates.join(', ')} 
      WHERE id = $${valueIndex} AND user_id = $${valueIndex + 1}
      RETURNING *
    `;

    const result = await pool.query(query, values);
    
    if (result.rows.length === 0) {
      return null;
    }

    return new Note(result.rows[0]);
  }

  static async delete(id, userId) {
    const query = 'DELETE FROM notes WHERE id = $1 AND user_id = $2 RETURNING *';
    const result = await pool.query(query, [id, userId]);
    
    return result.rows.length > 0;
  }

  static async deleteByPaperId(paperId, userId) {
    const query = 'DELETE FROM notes WHERE paper_id = $1 AND user_id = $2';
    const result = await pool.query(query, [paperId, userId]);
    
    return result.rowCount;
  }

  static async count(userId, paperId = null, search = '') {
    let query = 'SELECT COUNT(*) FROM notes WHERE user_id = $1';
    const values = [userId];

    if (paperId) {
      query += ' AND paper_id = $2';
      values.push(paperId);
    }

    if (search) {
      query += ` AND to_tsvector('english', content) @@ plainto_tsquery('english', $${values.length + 1})`;
      values.push(search);
    }

    const result = await pool.query(query, values);
    return parseInt(result.rows[0].count);
  }

  static async getNotesWithPaperInfo(userId, options = {}) {
    const { limit = 50, offset = 0, search = '' } = options;
    
    let query = `
      SELECT n.*, p.title as paper_title
      FROM notes n
      JOIN papers p ON n.paper_id = p.id
      WHERE n.user_id = $1
    `;
    const values = [userId];

    if (search) {
      query += ` AND (
        to_tsvector('english', n.content) @@ plainto_tsquery('english', $${values.length + 1})
        OR to_tsvector('english', p.title) @@ plainto_tsquery('english', $${values.length + 1})
      )`;
      values.push(search);
    }

    query += ` ORDER BY n.created_at DESC LIMIT $${values.length + 1} OFFSET $${values.length + 2}`;
    values.push(limit, offset);

    const result = await pool.query(query, values);
    return result.rows.map(row => ({
      ...new Note(row).toJSON(),
      paper_title: row.paper_title
    }));
  }

  toJSON() {
    return {
      id: this.id,
      paper_id: this.paper_id,
      user_id: this.user_id,
      content: this.content,
      page_number: this.page_number,
      position_x: this.position_x,
      position_y: this.position_y,
      created_at: this.created_at,
      updated_at: this.updated_at
    };
  }
}