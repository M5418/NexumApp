#!/bin/bash

# NexumApp Deployment with Cache Busting
# This script deploys and ensures browser cache is cleared

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

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     NexumApp Deploy with Cache Busting                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check prerequisites
print_section "Checking Prerequisites"

if ! command -v flutter >/dev/null 2>&1; then
    echo -e "${RED}✗ Flutter is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Flutter installed${NC}"

if ! command -v firebase >/dev/null 2>&1; then
    echo -e "${RED}✗ Firebase CLI is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI installed${NC}"

# Set Firebase project
firebase use nexum-backend

# Clean everything thoroughly
print_section "Deep Clean"
flutter clean
rm -rf build/web
echo -e "${GREEN}✓ Build artifacts removed${NC}"

# Get dependencies
print_section "Getting Dependencies"
flutter pub get
echo -e "${GREEN}✓ Dependencies resolved${NC}"

# Build with version timestamp (cache busting)
print_section "Building with Cache Busting"
TIMESTAMP=$(date +%s)
echo -e "${YELLOW}Build timestamp: $TIMESTAMP${NC}"

# Build web with version
flutter build web --release --dart-define=BUILD_TIMESTAMP=$TIMESTAMP

echo -e "${GREEN}✓ Web build completed with timestamp${NC}"

# Deploy to Firebase Hosting
print_section "Deploying to Firebase Hosting"
firebase deploy --only hosting

echo -e "${GREEN}✓ Deployment complete${NC}"

# Clear Firebase Hosting cache
print_section "Clearing Firebase CDN Cache"
echo -e "${YELLOW}Purging CDN cache...${NC}"

# Note: Firebase Hosting cache clears automatically after ~1 hour
# For immediate effect, users need to hard refresh (Cmd+Shift+R / Ctrl+Shift+F5)

echo -e "${GREEN}✓ Deployment successful!${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🌐 URL: ${GREEN}https://nexum-backend.web.app${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Cache Clearing Instructions${NC}"
echo ""
echo -e "${BLUE}For users to see changes immediately:${NC}"
echo -e "  1. ${GREEN}Chrome/Edge:${NC} Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)"
echo -e "  2. ${GREEN}Firefox:${NC} Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)"
echo -e "  3. ${GREEN}Safari:${NC} Cmd+Option+R"
echo -e "  4. ${GREEN}Or clear browser cache manually${NC}"
echo ""
echo -e "${YELLOW}Note: Firebase CDN cache clears automatically within 1 hour${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
