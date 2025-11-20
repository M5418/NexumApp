#!/bin/bash
# Build Nexum Consumer App for production with App Check

SITE_KEY="6LfqgwgsAAAAAIe8R2w8FHxSegdWhghKMe_8RUGK"

echo "🔨 Building Nexum Consumer App with App Check..."
flutter build web --release --dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=$SITE_KEY

echo "✅ Build complete! Deploy with: firebase deploy --only hosting"
