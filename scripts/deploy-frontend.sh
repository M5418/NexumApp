#!/bin/bash

# NexumApp Frontend Deployment Script
# This script builds and deploys the Flutter web app to Firebase Hosting

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
echo -e "${BLUE}║         NexumApp Frontend Deployment Script               ║${NC}"
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
echo -e "${GREEN}✓ Flutter installed$(flutter --version | head -n 1)${NC}"

if ! command -v firebase >/dev/null 2>&1; then
    echo -e "${RED}✗ Firebase CLI is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI installed${NC}"

# Set Firebase project
print_section "Setting Firebase Project"
firebase use nexum-backend
echo -e "${GREEN}✓ Using project: nexum-backend${NC}"

# Run linter
print_section "Running Flutter Analyzer"
echo -e "${YELLOW}Checking for lint errors...${NC}"
if flutter analyze; then
    echo -e "${GREEN}✓ No lint errors found${NC}"
else
    echo -e "${YELLOW}⚠ Lint warnings found, but continuing deployment...${NC}"
fi

# Clean build
print_section "Cleaning Build"
flutter clean
echo -e "${GREEN}✓ Build cleaned${NC}"

# Get dependencies
print_section "Getting Dependencies"
flutter pub get
echo -e "${GREEN}✓ Dependencies resolved${NC}"

# Build web app
print_section "Building Flutter Web App"
echo -e "${YELLOW}Building for production...${NC}"
flutter build web --release
echo -e "${GREEN}✓ Web build completed${NC}"

# Copy static HTML pages to build folder
print_section "Copying Static Pages"
cp web/terms-and-conditions.html build/web/
cp web/privacy-policy.html build/web/
echo -e "${GREEN}✓ Terms and Privacy pages copied${NC}"

# Deploy to Firebase Hosting
print_section "Deploying to Firebase Hosting"
firebase deploy --only hosting
echo -e "${GREEN}✓ Frontend deployed successfully${NC}"

# Summary
print_section "Frontend Deployment Complete!"
echo -e "${GREEN}✓ Your web app is live!${NC}"
echo ""
echo -e "${BLUE}URL:${NC} ${GREEN}https://nexum-backend.web.app${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
