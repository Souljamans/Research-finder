#!/bin/bash

# Research Paper Platform - Database Runner
# This script manages the PostgreSQL database using Docker Compose

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start the database container"
    echo "  stop      Stop the database container"
    echo "  restart   Restart the database container"
    echo "  status    Show database container status"
    echo "  logs      Show database container logs"
    echo "  reset     Stop, remove container and volumes, then start fresh"
    echo "  connect   Connect to database with psql"
    echo ""
}

start_db() {
    echo -e "${GREEN}Starting PostgreSQL database...${NC}"
    docker-compose up -d postgres
    echo -e "${GREEN}Database started successfully!${NC}"
    echo "Connection details:"
    echo "  Host: localhost"
    echo "  Port: 5432"
    echo "  Database: research_papers"
    echo "  Username: research_user"
    echo "  Password: research_pass"
}

stop_db() {
    echo -e "${YELLOW}Stopping PostgreSQL database...${NC}"
    docker-compose stop postgres
    echo -e "${YELLOW}Database stopped.${NC}"
}

restart_db() {
    stop_db
    start_db
}

show_status() {
    docker-compose ps postgres
}

show_logs() {
    docker-compose logs -f postgres
}

reset_db() {
    echo -e "${RED}This will destroy all data in the database!${NC}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Resetting database...${NC}"
        docker-compose down postgres
        docker volume rm research_postgres_data 2>/dev/null || true
        start_db
        echo -e "${GREEN}Database reset completed!${NC}"
    else
        echo "Reset cancelled."
    fi
}

connect_db() {
    echo -e "${GREEN}Connecting to database...${NC}"
    docker exec -it research_db psql -U research_user -d research_papers
}

# Main script logic
case "${1:-start}" in
    "start")
        start_db
        ;;
    "stop")
        stop_db
        ;;
    "restart")
        restart_db
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "reset")
        reset_db
        ;;
    "connect")
        connect_db
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac