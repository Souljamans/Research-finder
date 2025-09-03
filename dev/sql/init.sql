-- Initialize research papers database schema

-- Users table for authentication
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Papers table
CREATE TABLE papers (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    authors TEXT[],
    abstract TEXT,
    keywords TEXT[],
    file_path VARCHAR(500),
    file_size INTEGER,
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notes table
CREATE TABLE notes (
    id SERIAL PRIMARY KEY,
    paper_id INTEGER REFERENCES papers(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    page_number INTEGER,
    position_x FLOAT,
    position_y FLOAT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tags table
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    color VARCHAR(7) DEFAULT '#007bff'
);

-- Paper tags junction table
CREATE TABLE paper_tags (
    paper_id INTEGER REFERENCES papers(id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (paper_id, tag_id)
);

-- Create indexes for better search performance
CREATE INDEX idx_papers_title ON papers USING gin(to_tsvector('english', title));
CREATE INDEX idx_papers_abstract ON papers USING gin(to_tsvector('english', abstract));
CREATE INDEX idx_papers_authors ON papers USING gin(authors);
CREATE INDEX idx_papers_keywords ON papers USING gin(keywords);
CREATE INDEX idx_papers_user_id ON papers(user_id);
CREATE INDEX idx_notes_paper_id ON notes(paper_id);
CREATE INDEX idx_notes_user_id ON notes(user_id);