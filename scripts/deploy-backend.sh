#!/bin/bash

# NexumApp Backend Deployment Script
# This script deploys Firebase backend services (Firestore, Storage, Functions)

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
echo -e "${BLUE}║         NexumApp Backend Deployment Script                ║${NC}"
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

if ! command -v firebase >/dev/null 2>&1; then
    echo -e "${RED}✗ Firebase CLI is not installed${NC}"
    echo -e "${YELLOW}Install with: brew install firebase-cli${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI installed (v$(firebase --version))${NC}"

# Check if logged in
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

# Deploy Firestore
print_section "Deploying Firestore"
echo -e "${YELLOW}Deploying database rules and indexes...${NC}"
firebase deploy --only firestore
echo -e "${GREEN}✓ Firestore deployed successfully${NC}"

# Deploy Storage
print_section "Deploying Storage"
echo -e "${YELLOW}Deploying storage rules...${NC}"
firebase deploy --only storage
echo -e "${GREEN}✓ Storage deployed successfully${NC}"

# Deploy Functions
print_section "Deploying Cloud Functions"
echo -e "${YELLOW}Deploying functions...${NC}"
firebase deploy --only functions
echo -e "${GREEN}✓ Functions deployed successfully${NC}"

# Summary
print_section "Backend Deployment Complete!"
echo -e "${GREEN}✓ All backend services deployed!${NC}"
echo ""
echo -e "${BLUE}Services deployed:${NC}"
echo -e "${GREEN}  ✓ Firestore Database (rules + indexes)${NC}"
echo -e "${GREEN}  ✓ Cloud Storage (rules)${NC}"
echo -e "${GREEN}  ✓ Cloud Functions${NC}"
echo ""
echo -e "${BLUE}Project Console:${NC}"
echo -e "${GREEN}📊 https://console.firebase.google.com/project/nexum-backend/overview${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
