#!/bin/bash
# Run Nexum Consumer App with reCAPTCHA Enterprise App Check

SITE_KEY="6LfqgwgsAAAAAIe8R2w8FHxSegdWhghKMe_8RUGK"

flutter run -d chrome --dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=$SITE_KEY
