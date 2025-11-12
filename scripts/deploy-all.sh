#!/bin/bash

# NexumApp Complete Deployment Script
# This script deploys both frontend (Flutter web) and backend (Firebase services)
# Includes cache busting to ensure UI changes are immediately visible

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
echo -e "${BLUE}║       NexumApp Complete Deployment Script                 ║${NC}"
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_section "Checking Prerequisites"

if ! command_exists flutter; then
    echo -e "${RED}✗ Flutter is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Flutter installed$(flutter --version | head -n 1)${NC}"

if ! command_exists firebase; then
    echo -e "${RED}✗ Firebase CLI is not installed${NC}"
    echo -e "${YELLOW}Install with: brew install firebase-cli${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI installed (v$(firebase --version))${NC}"

# Check if logged in to Firebase
if ! firebase projects:list >/dev/null 2>&1; then
    echo -e "${RED}✗ Not logged in to Firebase${NC}"
    echo -e "${YELLOW}Running firebase login...${NC}"
    firebase login
fi
echo -e "${GREEN}✓ Firebase authenticated${NC}"

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
    echo -e "${RED}✗ Lint errors found. Please fix them before deploying.${NC}"
    exit 1
fi

# Deep Clean (including web build for cache busting)
print_section "Deep Clean (Cache Busting)"
flutter clean
rm -rf build/web
echo -e "${GREEN}✓ Build artifacts removed completely${NC}"

# Get Flutter dependencies
print_section "Getting Flutter Dependencies"
flutter pub get
echo -e "${GREEN}✓ Dependencies resolved${NC}"

# Build Flutter Web
print_section "Building Flutter Web App"
echo -e "${YELLOW}Building for production (this may take a few minutes)...${NC}"
flutter build web --release
echo -e "${GREEN}✓ Flutter web build completed${NC}"

# Deploy Frontend (Hosting)
print_section "Deploying Frontend (Firebase Hosting)"
firebase deploy --only hosting
echo -e "${GREEN}✓ Frontend deployed successfully${NC}"

# Deploy Backend Services
print_section "Deploying Backend (Firestore, Storage, Functions)"

# Deploy Firestore
echo -e "${YELLOW}Deploying Firestore rules and indexes...${NC}"
firebase deploy --only firestore
echo -e "${GREEN}✓ Firestore deployed${NC}"

# Deploy Storage
echo -e "${YELLOW}Deploying Storage rules...${NC}"
firebase deploy --only storage
echo -e "${GREEN}✓ Storage deployed${NC}"

# Deploy Functions
echo -e "${YELLOW}Deploying Cloud Functions...${NC}"
firebase deploy --only functions
echo -e "${GREEN}✓ Functions deployed${NC}"

# Final summary
print_section "Deployment Complete!"
echo -e "${GREEN}✓ All services deployed successfully!${NC}"
echo ""
echo -e "${BLUE}Your app is live at:${NC}"
echo -e "${GREEN}🌐 https://nexum-backend.web.app${NC}"
echo ""
echo -e "${BLUE}Project Console:${NC}"
echo -e "${GREEN}📊 https://console.firebase.google.com/project/nexum-backend/overview${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Cache Clearing Instructions${NC}"
echo ""
echo -e "${BLUE}For users to see changes immediately, they should:${NC}"
echo -e "  1. ${GREEN}Chrome/Edge:${NC} Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)"
echo -e "  2. ${GREEN}Firefox:${NC} Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)"
echo -e "  3. ${GREEN}Safari:${NC} Cmd+Option+R"
echo -e "  4. ${GREEN}Or clear browser cache manually${NC}"
echo ""
echo -e "${YELLOW}Note: Firebase CDN cache clears automatically within 1 hour${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
