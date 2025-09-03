# Research Paper Management Platform

A full-stack application for managing research papers with PDF upload, note-taking, and search capabilities.

## Quick Start

1. **Start the database:**
   ```bash
   ./dev/sh/runDB.sh
   ```

2. **Install dependencies:**
   ```bash
   npm run setup
   ```

3. **Start development servers:**
   ```bash
   # Terminal 1 - Backend
   npm run dev:backend
   
   # Terminal 2 - Frontend  
   npm run dev:frontend
   ```

4. **Access the application:**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:3001
   - Health Check: http://localhost:3001/api/health

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
├── frontend/           # React frontend
├── backend/            # Express.js backend
├── dev/
│   ├── sh/
│   │   └── runDB.sh   # Database management script
│   └── sql/
│       └── init.sql   # Database initialization
├── storage/
│   └── pdfs/          # PDF file storage
└── docker-compose.yml # Database container config
```

## Phase 1 Complete ✅

- [x] Project structure initialized
- [x] Docker-based PostgreSQL database with runDB.sh script
- [x] File storage system for PDFs
- [x] Authentication system with JWT
- [x] Development environment configured

Ready for Phase 2: Core Data Models & API development.