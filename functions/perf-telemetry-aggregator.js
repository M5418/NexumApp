/**
 * Cloud Function: Performance Telemetry Aggregator
 * 
 * Scheduled function that runs every 15 minutes to:
 * 1. Aggregate performance telemetry from Firestore
 * 2. Detect degraded performance across user segments
 * 3. Automatically adjust Remote Config to lite mode if needed
 * 4. Restore to normal mode when metrics recover
 * 
 * Privacy: Only processes anonymized metrics, no PII.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Thresholds for triggering lite mode
const THRESHOLDS = {
  jankRate: 0.20,           // 20% janky frames
  feedLoadP95Ms: 3000,      // 3 seconds
  chatLoadP95Ms: 2000,      // 2 seconds
  videoInitP95Ms: 4000,     // 4 seconds
  minSampleSize: 50,        // Minimum telemetry samples to make decision
  degradedSessionPercent: 0.25, // 25% of sessions must be degraded
};

// Cooldown settings
const COOLDOWN_HOURS = 2;   // Keep lite mode for at least 2 hours
const RECOVERY_HOURS = 1;   // Require 1 hour of good metrics to restore

/**
 * Scheduled function: Runs every 15 minutes
 */
exports.aggregatePerfTelemetry = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async (context) => {
    console.log('🔄 Starting performance telemetry aggregation...');

    try {
      // Get telemetry from last 30 minutes
      const cutoff = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 30 * 60 * 1000)
      );

      const telemetrySnap = await db.collection('perf_telemetry')
        .where('timestamp', '>=', cutoff)
        .get();

      if (telemetrySnap.size < THRESHOLDS.minSampleSize) {
        console.log(`⏭️ Insufficient samples (${telemetrySnap.size}/${THRESHOLDS.minSampleSize}), skipping`);
        return null;
      }

      // Aggregate metrics
      const metrics = aggregateMetrics(telemetrySnap.docs);
      console.log('📊 Aggregated metrics:', JSON.stringify(metrics));

      // Check current Remote Config state
      const configState = await getConfigState();
      
      // Determine if we should change mode
      const shouldBeLite = shouldEnableLiteMode(metrics);
      const isCurrentlyLite = configState.currentMode === 'lite';

      if (shouldBeLite && !isCurrentlyLite) {
        // Check cooldown before switching to lite
        if (canSwitchToLite(configState)) {
          await enableLiteMode(metrics);
          console.log('⬇️ Switched to LITE mode due to degraded performance');
        } else {
          console.log('⏳ Would switch to lite but in cooldown period');
        }
      } else if (!shouldBeLite && isCurrentlyLite) {
        // Check recovery period before restoring normal
        if (canRestoreNormal(configState)) {
          await restoreNormalMode();
          console.log('⬆️ Restored to NORMAL mode - metrics recovered');
        } else {
          console.log('⏳ Metrics improving but not yet stable enough to restore');
        }
      } else {
        console.log(`✅ No change needed (current: ${configState.currentMode})`);
      }

      // Store aggregation result for monitoring
      await db.collection('perf_aggregations').add({
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        metrics,
        sampleSize: telemetrySnap.size,
        decision: shouldBeLite ? 'lite' : 'normal',
        currentMode: configState.currentMode,
      });

      return null;
    } catch (error) {
      console.error('❌ Aggregation error:', error);
      return null;
    }
  });

/**
 * Aggregate metrics from telemetry documents
 */
function aggregateMetrics(docs) {
  const jankRates = [];
  const feedP95s = [];
  const chatP95s = [];
  const videoP95s = [];
  let degradedSessions = 0;

  for (const doc of docs) {
    const data = doc.data();
    const m = data.metrics || {};

    if (typeof m.jankRate === 'number') jankRates.push(m.jankRate);
    if (typeof m.feedLoadP95Ms === 'number' && m.feedLoadP95Ms > 0) feedP95s.push(m.feedLoadP95Ms);
    if (typeof m.chatLoadP95Ms === 'number' && m.chatLoadP95Ms > 0) chatP95s.push(m.chatLoadP95Ms);
    if (typeof m.videoInitP95Ms === 'number' && m.videoInitP95Ms > 0) videoP95s.push(m.videoInitP95Ms);

    // Count degraded sessions
    if (m.isInLiteMode === true) {
      degradedSessions++;
    }
  }

  return {
    avgJankRate: average(jankRates),
    p95JankRate: percentile(jankRates, 95),
    avgFeedP95Ms: average(feedP95s),
    avgChatP95Ms: average(chatP95s),
    avgVideoP95Ms: average(videoP95s),
    degradedSessionPercent: docs.length > 0 ? degradedSessions / docs.length : 0,
    sampleCount: docs.length,
  };
}

/**
 * Determine if lite mode should be enabled
 */
function shouldEnableLiteMode(metrics) {
  // Check if significant portion of sessions are degraded
  if (metrics.degradedSessionPercent >= THRESHOLDS.degradedSessionPercent) {
    return true;
  }

  // Check individual thresholds
  if (metrics.p95JankRate >= THRESHOLDS.jankRate) return true;
  if (metrics.avgFeedP95Ms >= THRESHOLDS.feedLoadP95Ms) return true;
  if (metrics.avgChatP95Ms >= THRESHOLDS.chatLoadP95Ms) return true;
  if (metrics.avgVideoP95Ms >= THRESHOLDS.videoInitP95Ms) return true;

  return false;
}

/**
 * Get current Remote Config state from Firestore
 */
async function getConfigState() {
  const stateDoc = await db.collection('perf_config_state').doc('current').get();
  if (!stateDoc.exists) {
    return {
      currentMode: 'normal',
      lastModeChange: null,
      consecutiveGoodChecks: 0,
    };
  }
  return stateDoc.data();
}

/**
 * Check if we can switch to lite mode (cooldown check)
 */
function canSwitchToLite(configState) {
  if (!configState.lastModeChange) return true;
  
  const lastChange = configState.lastModeChange.toDate();
  const hoursSinceChange = (Date.now() - lastChange.getTime()) / (1000 * 60 * 60);
  
  // Don't flap - require some time since last change
  return hoursSinceChange >= 0.25; // 15 minutes minimum
}

/**
 * Check if we can restore normal mode (recovery check)
 */
function canRestoreNormal(configState) {
  if (!configState.lastModeChange) return true;
  
  const lastChange = configState.lastModeChange.toDate();
  const hoursSinceChange = (Date.now() - lastChange.getTime()) / (1000 * 60 * 60);
  
  // Require sustained good metrics before restoring
  return hoursSinceChange >= RECOVERY_HOURS && 
         (configState.consecutiveGoodChecks || 0) >= 4; // 4 consecutive good checks (1 hour)
}

/**
 * Enable lite mode via Remote Config
 */
async function enableLiteMode(metrics) {
  const remoteConfig = admin.remoteConfig();
  
  try {
    const template = await remoteConfig.getTemplate();
    
    // Update parameters
    template.parameters['perf_mode_global'] = {
      defaultValue: { value: 'lite' },
    };
    template.parameters['kill_switch_video_autoplay'] = {
      defaultValue: { value: 'true' },
    };
    template.parameters['kill_switch_prefetch'] = {
      defaultValue: { value: 'true' },
    };
    template.parameters['perf_feed_page_size'] = {
      defaultValue: { value: '6' },
    };

    await remoteConfig.publishTemplate(template);
    console.log('✅ Remote Config updated to lite mode');

    // Update state
    await db.collection('perf_config_state').doc('current').set({
      currentMode: 'lite',
      lastModeChange: admin.firestore.FieldValue.serverTimestamp(),
      consecutiveGoodChecks: 0,
      triggerMetrics: metrics,
    });
  } catch (error) {
    console.error('❌ Failed to update Remote Config:', error);
    throw error;
  }
}

/**
 * Restore normal mode via Remote Config
 */
async function restoreNormalMode() {
  const remoteConfig = admin.remoteConfig();
  
  try {
    const template = await remoteConfig.getTemplate();
    
    // Restore normal parameters
    template.parameters['perf_mode_global'] = {
      defaultValue: { value: 'normal' },
    };
    template.parameters['kill_switch_video_autoplay'] = {
      defaultValue: { value: 'false' },
    };
    template.parameters['kill_switch_prefetch'] = {
      defaultValue: { value: 'false' },
    };
    template.parameters['perf_feed_page_size'] = {
      defaultValue: { value: '10' },
    };

    await remoteConfig.publishTemplate(template);
    console.log('✅ Remote Config restored to normal mode');

    // Update state
    await db.collection('perf_config_state').doc('current').set({
      currentMode: 'normal',
      lastModeChange: admin.firestore.FieldValue.serverTimestamp(),
      consecutiveGoodChecks: 0,
    });
  } catch (error) {
    console.error('❌ Failed to restore Remote Config:', error);
    throw error;
  }
}

// Helper: Calculate average
function average(arr) {
  if (arr.length === 0) return 0;
  return arr.reduce((a, b) => a + b, 0) / arr.length;
}

// Helper: Calculate percentile
function percentile(arr, p) {
  if (arr.length === 0) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const index = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, index)];
}

/**
 * HTTP endpoint to manually trigger aggregation (for testing)
 */
exports.triggerPerfAggregation = functions.https.onRequest(async (req, res) => {
  // Only allow POST requests
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  try {
    // Run the same logic as scheduled function
    console.log('🔄 Manual aggregation triggered...');
    
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 30 * 60 * 1000)
    );

    const telemetrySnap = await db.collection('perf_telemetry')
      .where('timestamp', '>=', cutoff)
      .get();

    const metrics = aggregateMetrics(telemetrySnap.docs);
    const configState = await getConfigState();
    const shouldBeLite = shouldEnableLiteMode(metrics);

    res.json({
      success: true,
      sampleSize: telemetrySnap.size,
      metrics,
      currentMode: configState.currentMode,
      recommendation: shouldBeLite ? 'lite' : 'normal',
    });
  } catch (error) {
    console.error('❌ Manual aggregation error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * HTTP endpoint to force a specific mode (emergency use)
 */
exports.forcePerformanceMode = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const mode = req.body.mode;
  if (!['normal', 'lite', 'ultra'].includes(mode)) {
    res.status(400).json({ error: 'Invalid mode. Use: normal, lite, or ultra' });
    return;
  }

  try {
    if (mode === 'normal') {
      await restoreNormalMode();
    } else {
      await enableLiteMode({ forced: true, mode });
    }

    res.json({ success: true, mode });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
