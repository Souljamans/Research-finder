# Research Paper Management Platform

A Phoenix/Elixir application for managing research papers with PDF upload, note-taking, and search capabilities.

## Quick Start

1. **Start the database:**
   ```bash
   ./dev/sh/runDB.sh
   ```

2. **Install dependencies and setup:**
   ```bash
   cd research_phoenix
   mix setup
   ```

3. **Start the Phoenix server:**
   ```bash
   cd research_phoenix
   mix phx.server
   ```

4. **Access the application:**
   - Web Application: http://localhost:4000
   - LiveDashboard: http://localhost:4000/dev/dashboard

## Database Management

The database can be managed using the `dev/sh/runDB.sh` script:

```bash
./dev/sh/runDB.sh start    # Start database
./dev/sh/runDB.sh stop     # Stop database
./dev/sh/runDB.sh restart  # Restart database
./dev/sh/runDB.sh status   # Check status
./dev/sh/runDB.sh logs     # View logs
./dev/sh/runDB.sh reset    # Reset database (destroys data)
./dev/sh/runDB.sh connect  # Connect via psql
```

## Project Structure

```
├── research_phoenix/   # Phoenix/Elixir application
│   ├── lib/           # Application code
│   ├── assets/        # Frontend assets (JS/CSS)
│   ├── priv/          # Database migrations, static assets
│   └── test/          # Test files
├── dev/
│   ├── sh/
│   │   └── runDB.sh   # Database management script
│   └── sql/
│       └── init.sql   # Database initialization
├── storage/
│   └── pdfs/          # PDF file storage
└── docker-compose.yml # Database container config
```

## Technology Stack

- **Framework**: Phoenix 1.8 with LiveView
- **Language**: Elixir 1.15+
- **Database**: PostgreSQL with Ecto
- **Frontend**: Phoenix LiveView, Tailwind CSS, DaisyUI
- **File Processing**: PDF processing with Elixir libraries
- **Authentication**: Phoenix.Token and Bcrypt

## Development Status

### ✅ Phase 1: Project Setup & Infrastructure
- [x] Phoenix project initialized with LiveView
- [x] Docker-based PostgreSQL database with runDB.sh script
- [x] File storage system for PDFs
- [x] Authentication system with Phoenix.Token
- [x] Development environment configured

### ✅ Phase 2: Core Data Models & API  
- [x] Database schema for papers, authors, notes, tags
- [x] Paper and Notes models with full CRUD operations
- [x] LiveView interfaces for paper management
- [x] File upload and PDF processing system
- [x] Full-text search capabilities with PostgreSQL

### ✅ Phase 3: PDF Upload & Processing
- [x] PDF upload functionality with validation
- [x] PDF text extraction and metadata parsing
- [x] File storage and retrieval system
- [x] Progress indicators and error handling
- [x] PDF viewer integration

**Current**: Fully functional Phoenix application with PDF management, search, and user interface
