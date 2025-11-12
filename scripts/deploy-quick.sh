#!/bin/bash

# NexumApp Quick Deployment Script
# Fast deployment without cleaning or linting (use only when you're confident)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}⚡ Quick Deploy Mode (skipping clean & lint)${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Check prerequisites
if ! command -v flutter >/dev/null 2>&1 || ! command -v firebase >/dev/null 2>&1; then
    echo -e "${RED}✗ Missing prerequisites${NC}"
    exit 1
fi

# Set Firebase project
firebase use nexum-backend

# Build web app
echo -e "${BLUE}Building Flutter web...${NC}"
flutter build web --release
echo -e "${GREEN}✓ Build complete${NC}"

# Deploy all
echo -e "${BLUE}Deploying all services...${NC}"
firebase deploy
echo -e "${GREEN}✓ Deployment complete${NC}"

echo ""
echo -e "${GREEN}🚀 Quick deploy successful!${NC}"
echo -e "${GREEN}🌐 https://nexum-backend.web.app${NC}"
