import { pool } from '../config/database.js';

export class Paper {
  constructor({
    id,
    title,
    authors,
    abstract,
    keywords,
    file_path,
    file_size,
    upload_date,
    user_id,
    metadata,
    created_at,
    updated_at
  }) {
    this.id = id;
    this.title = title;
    this.authors = authors || [];
    this.abstract = abstract;
    this.keywords = keywords || [];
    this.file_path = file_path;
    this.file_size = file_size;
    this.upload_date = upload_date;
    this.user_id = user_id;
    this.metadata = metadata || {};
    this.created_at = created_at;
    this.updated_at = updated_at;
  }

  static async create(paperData) {
    const {
      title,
      authors = [],
      abstract = '',
      keywords = [],
      file_path,
      file_size,
      user_id,
      metadata = {}
    } = paperData;

    const query = `
      INSERT INTO papers (title, authors, abstract, keywords, file_path, file_size, user_id, metadata)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *
    `;

    const values = [
      title,
      authors,
      abstract,
      keywords,
      file_path,
      file_size,
      user_id,
      JSON.stringify(metadata)
    ];

    const result = await pool.query(query, values);
    return new Paper(result.rows[0]);
  }

  static async findById(id, userId) {
    const query = 'SELECT * FROM papers WHERE id = $1 AND user_id = $2';
    const result = await pool.query(query, [id, userId]);
    
    if (result.rows.length === 0) {
      return null;
    }

    return new Paper(result.rows[0]);
  }

  static async findByUserId(userId, options = {}) {
    const { limit = 50, offset = 0, search = '', sortBy = 'created_at', sortOrder = 'DESC' } = options;
    
    let query = 'SELECT * FROM papers WHERE user_id = $1';
    const values = [userId];

    if (search) {
      query += ` AND (
        to_tsvector('english', title) @@ plainto_tsquery('english', $${values.length + 1})
        OR to_tsvector('english', abstract) @@ plainto_tsquery('english', $${values.length + 1})
        OR $${values.length + 1} = ANY(authors)
        OR $${values.length + 1} = ANY(keywords)
      )`;
      values.push(search);
    }

    query += ` ORDER BY ${sortBy} ${sortOrder} LIMIT $${values.length + 1} OFFSET $${values.length + 2}`;
    values.push(limit, offset);

    const result = await pool.query(query, values);
    return result.rows.map(row => new Paper(row));
  }

  static async update(id, userId, updateData) {
    const allowedFields = ['title', 'authors', 'abstract', 'keywords', 'metadata'];
    const updates = [];
    const values = [];
    let valueIndex = 1;

    Object.keys(updateData).forEach(key => {
      if (allowedFields.includes(key)) {
        updates.push(`${key} = $${valueIndex}`);
        values.push(key === 'metadata' ? JSON.stringify(updateData[key]) : updateData[key]);
        valueIndex++;
      }
    });

    if (updates.length === 0) {
      throw new Error('No valid fields to update');
    }

    updates.push(`updated_at = CURRENT_TIMESTAMP`);
    values.push(id, userId);

    const query = `
      UPDATE papers 
      SET ${updates.join(', ')} 
      WHERE id = $${valueIndex} AND user_id = $${valueIndex + 1}
      RETURNING *
    `;

    const result = await pool.query(query, values);
    
    if (result.rows.length === 0) {
      return null;
    }

    return new Paper(result.rows[0]);
  }

  static async delete(id, userId) {
    const query = 'DELETE FROM papers WHERE id = $1 AND user_id = $2 RETURNING *';
    const result = await pool.query(query, [id, userId]);
    
    return result.rows.length > 0;
  }

  static async count(userId, search = '') {
    let query = 'SELECT COUNT(*) FROM papers WHERE user_id = $1';
    const values = [userId];

    if (search) {
      query += ` AND (
        to_tsvector('english', title) @@ plainto_tsquery('english', $2)
        OR to_tsvector('english', abstract) @@ plainto_tsquery('english', $2)
        OR $2 = ANY(authors)
        OR $2 = ANY(keywords)
      )`;
      values.push(search);
    }

    const result = await pool.query(query, values);
    return parseInt(result.rows[0].count);
  }

  toJSON() {
    return {
      id: this.id,
      title: this.title,
      authors: this.authors,
      abstract: this.abstract,
      keywords: this.keywords,
      file_path: this.file_path,
      file_size: this.file_size,
      upload_date: this.upload_date,
      user_id: this.user_id,
      metadata: this.metadata,
      created_at: this.created_at,
      updated_at: this.updated_at
    };
  }
}