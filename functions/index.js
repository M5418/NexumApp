const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onDocumentWritten, onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
admin.initializeApp();

// Export Firestore triggers (likes, bookmarks, repost counters)
Object.assign(exports, require('./triggers'));

// Reverse proxy to legacy backend so the web app can call same-origin /api/**
// TARGET is configurable via env; defaults to production legacy API.
const TARGET = process.env.LEGACY_API_BASE || "https://api.nexum-connects.com";

// DeepL API configuration
// Set DEEPL_API_KEY in Firebase Functions environment config:
// firebase functions:config:set deepl.api_key="YOUR_DEEPL_PRO_API_KEY"
const DEEPL_API_KEY = process.env.DEEPL_API_KEY || "";
const DEEPL_API_URL = "https://api.deepl.com/v2/translate";

exports.api = onRequest({ region: "us-central1", cors: true }, async (req, res) => {
  const origin = req.get("Origin") || "*";
  res.set("Access-Control-Allow-Origin", origin);
  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
  res.set("Access-Control-Allow-Headers", req.get("Access-Control-Request-Headers") || "Content-Type, Authorization");
  res.set("Access-Control-Allow-Credentials", "true");
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const url = new URL(req.url, `https://${req.get("host")}`);
    // Strip the /api prefix so "/api/auth/login" -> "/auth/login"
    const forwardPath = url.pathname.replace(/^\/api(\/|$)/, "/");
    const targetUrl = `${TARGET}${forwardPath}${url.search}`;

    // Build headers, excluding hop-by-hop and host
    const headers = new Headers();
    for (const [k, v] of Object.entries(req.headers)) {
      const key = k.toLowerCase();
      if (["host", "connection", "accept-encoding"].includes(key)) continue;
      // Skip cookie forwarding unless you know legacy uses cookie auth
      if (key === "cookie") continue;
      headers.append(k, Array.isArray(v) ? v.join(", ") : v);
    }

    const init = {
      method: req.method,
      headers,
      body: ["GET", "HEAD"].includes(req.method) ? undefined : req.rawBody,
    };

    logger.info("Proxying request", { method: req.method, path: forwardPath, target: targetUrl });
    const resp = await fetch(targetUrl, init);
    const buf = Buffer.from(await resp.arrayBuffer());

    // Propagate content-type and status
    const contentType = resp.headers.get("content-type");
    if (contentType) res.set("Content-Type", contentType);
    res.status(resp.status).send(buf);
  } catch (err) {
    logger.error("Proxy error", { error: err?.message || String(err) });
    res.status(502).json({ ok: false, error: "Bad gateway", detail: String(err) });
  }
});

// Translation function using DeepL Pro API
exports.translateTexts = onCall({ region: "us-central1" }, async (request) => {
  try {
    const { texts, target_lang } = request.data;

    if (!texts || !Array.isArray(texts) || texts.length === 0) {
      throw new Error("'texts' must be a non-empty array");
    }

    if (!target_lang || typeof target_lang !== "string") {
      throw new Error("'target_lang' must be a valid language code (e.g., 'EN', 'FR', 'ES')");
    }

    if (!DEEPL_API_KEY) {
      logger.error("DeepL API key is not configured");
      // Return original texts if API key is missing
      return { translations: texts };
    }

    // Prepare the request body for DeepL API
    const params = new URLSearchParams();
    texts.forEach((text) => params.append("text", text));
    params.append("target_lang", target_lang);

    logger.info("Translating texts", { 
      count: texts.length, 
      target_lang,
      first_text_preview: texts[0]?.substring(0, 50)
    });

    // Call DeepL API
    const response = await fetch(DEEPL_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `DeepL-Auth-Key ${DEEPL_API_KEY}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("DeepL API error", { 
        status: response.status, 
        statusText: response.statusText,
        error: errorText
      });
      // Return original texts on API error
      return { translations: texts };
    }

    const data = await response.json();
    
    if (!data.translations || !Array.isArray(data.translations)) {
      logger.error("Invalid response from DeepL API", { data });
      return { translations: texts };
    }

    const translations = data.translations.map((item) => item.text || "");

    logger.info("Translation successful", { count: translations.length });

    return { translations };
  } catch (error) {
    logger.error("Translation function error", { error: error.message });
    // Return original texts on any error
    return { translations: request.data.texts || [] };
  }
});

// Agora Token Generation for Live Streaming
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');
const functions = require('firebase-functions');

// Get Agora credentials from Firebase config or environment
const getAgoraConfig = () => {
  // Try Firebase Functions config first (legacy)
  try {
    const config = functions.config();
    if (config.agora && config.agora.app_certificate) {
      return {
        appId: config.agora.app_id || "371cf61b84c0427d84471c91e71435cd",
        appCertificate: config.agora.app_certificate
      };
    }
  } catch (e) {
    // Config not available
  }
  // Fallback to environment variables
  return {
    appId: process.env.AGORA_APP_ID || "371cf61b84c0427d84471c91e71435cd",
    appCertificate: process.env.AGORA_APP_CERTIFICATE || ""
  };
};

const AGORA_APP_ID = "371cf61b84c0427d84471c91e71435cd";
const AGORA_APP_CERTIFICATE = "0f3dae78a0b545988066cd25794a4ab8";

const buildAgoraToken = (appId, appCertificate, channelName, uid, role, privilegeExpiredTs) => {
  if (!appCertificate) {
    logger.warn("No Agora App Certificate configured - using empty token");
    return "";
  }
  
  const agoraRole = role === 1 ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
  return RtcTokenBuilder.buildTokenWithUid(appId, appCertificate, channelName, uid, agoraRole, privilegeExpiredTs);
};

exports.generateAgoraToken = onCall({ region: "us-central1" }, async (request) => {
  // Note: Authentication is optional for token generation
  // The token itself provides security for the Agora channel
  const { channelName, uid, role } = request.data;
  
  if (!channelName) {
    throw new Error("Channel name is required");
  }

  const userUid = uid || Math.floor(Math.random() * 100000);
  const userRole = role === "publisher" ? 1 : 2; // 1 = publisher, 2 = subscriber
  
  // Token expires in 24 hours
  const expirationTimeInSeconds = 86400;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  try {
    const token = buildAgoraToken(
      AGORA_APP_ID,
      AGORA_APP_CERTIFICATE,
      channelName,
      userUid,
      userRole,
      privilegeExpiredTs
    );

    logger.info("Agora token generated", { channelName, uid: userUid, role: userRole });

    return {
      token,
      uid: userUid,
      channelName,
      appId: AGORA_APP_ID,
    };
  } catch (error) {
    logger.error("Error generating Agora token", { error: error.message });
    throw new Error("Failed to generate token");
  }
});

// ============================================
// PUSH NOTIFICATIONS
// ============================================

const db = admin.firestore();
const messaging = admin.messaging();

// Helper: Get user's FCM tokens
async function getUserFcmTokens(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return [];
  const data = userDoc.data();
  return data.fcmTokens || [];
}

// Helper: Send push notification to user
async function sendPushToUser(userId, title, body, data = {}) {
  const tokens = await getUserFcmTokens(userId);
  if (tokens.length === 0) {
    logger.info('No FCM tokens for user', { userId });
    return;
  }

  const message = {
    notification: {
      title,
      body,
    },
    data: {
      ...data,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
    android: {
      notification: {
        sound: 'default',
        priority: 'high',
      },
    },
  };

  // Send to all user's devices
  const sendPromises = tokens.map(async (token) => {
    try {
      await messaging.send({ ...message, token });
      logger.info('Push sent', { userId, token: token.substring(0, 20) + '...' });
    } catch (error) {
      // Remove invalid tokens
      if (error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered') {
        logger.info('Removing invalid token', { userId });
        await db.collection('users').doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(token)
        });
      } else {
        logger.error('Push send error', { error: error.message });
      }
    }
  });

  await Promise.all(sendPromises);
}

// 1. PUSH FOR NEW NOTIFICATIONS (in-app notifications trigger push)
exports.onNotificationCreated = onDocumentCreated(
  { document: 'users/{userId}/notifications/{notificationId}', region: 'us-central1' },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notification = snapshot.data();
    const userId = event.params.userId;

    // Send push notification
    await sendPushToUser(
      userId,
      notification.title || 'New Notification',
      notification.body || 'You have a new notification',
      {
        type: notification.type || 'notification',
        refId: notification.refId || '',
        notificationId: event.params.notificationId,
      }
    );
  }
);

// 2. PUSH FOR NEW MESSAGES
exports.onMessageCreated = onDocumentCreated(
  { document: 'conversations/{conversationId}/messages/{messageId}', region: 'us-central1' },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const message = snapshot.data();
    const conversationId = event.params.conversationId;
    const senderId = message.senderId;

    // Skip if no sender ID
    if (!senderId) {
      logger.info('No senderId in message, skipping push');
      return;
    }

    // Get conversation to find recipient
    const convDoc = await db.collection('conversations').doc(conversationId).get();
    if (!convDoc.exists) {
      logger.info('Conversation not found', { conversationId });
      return;
    }

    const convData = convDoc.data();
    const participants = convData.participants || [];
    
    // Find ALL recipients (everyone except the sender)
    const recipients = participants.filter(p => p && p !== senderId);
    
    if (recipients.length === 0) {
      logger.info('No recipients found (sender is only participant)', { senderId, participants });
      return;
    }
    
    // For 1-on-1 chats, there should be exactly one recipient
    const recipientId = recipients[0];
    
    // Double-check: NEVER send notification to the sender
    if (recipientId === senderId) {
      logger.error('BUG: recipientId equals senderId, aborting', { senderId, recipientId });
      return;
    }

    // Check if recipient has muted sender
    const muteCheck = await db.collection('mutes')
      .where('mutedByUid', '==', recipientId)
      .where('mutedUid', '==', senderId)
      .limit(1)
      .get();
    
    if (!muteCheck.empty) {
      logger.info('Sender is muted, skipping push', { senderId, recipientId });
      return;
    }

    // Get sender name
    const senderDoc = await db.collection('users').doc(senderId).get();
    const senderName = senderDoc.exists ? 
      (senderDoc.data().firstName || senderDoc.data().username || 'Someone') : 'Someone';

    // Determine message preview
    let messagePreview = message.text || '';
    if (message.mediaUrls && message.mediaUrls.length > 0) {
      messagePreview = messagePreview || '📷 Sent a photo';
    }
    if (message.audioUrl) {
      messagePreview = '🎤 Sent a voice message';
    }
    if (messagePreview.length > 100) {
      messagePreview = messagePreview.substring(0, 100) + '...';
    }

    await sendPushToUser(
      recipientId,
      senderName,
      messagePreview,
      {
        type: 'message',
        conversationId,
        senderId,
      }
    );
  }
);

// 3. PUSH FOR NEW CONNECTION REQUEST (follow)
exports.onFollowCreated = onDocumentCreated(
  { document: 'follows/{followId}', region: 'us-central1' },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const follow = snapshot.data();
    const followerId = follow.followerId;
    const followingId = follow.followingId;

    // Get follower name
    const followerDoc = await db.collection('users').doc(followerId).get();
    const followerName = followerDoc.exists ? 
      (followerDoc.data().firstName || followerDoc.data().username || 'Someone') : 'Someone';

    // Check if this is a mutual connection (they already follow back)
    const mutualCheck = await db.collection('follows')
      .where('followerId', '==', followingId)
      .where('followingId', '==', followerId)
      .limit(1)
      .get();

    if (!mutualCheck.empty) {
      // Mutual connection - notify both
      await sendPushToUser(
        followingId,
        'New Connection! 🎉',
        `${followerName} connected with you`,
        { type: 'connection', userId: followerId }
      );
    } else {
      // New connection request
      await sendPushToUser(
        followingId,
        'New Connection Request',
        `${followerName} wants to connect with you`,
        { type: 'connection_request', userId: followerId }
      );
    }
  }
);

// 4. PUSH FOR NEW POST FROM CONNECTIONS
exports.onPostCreated = onDocumentCreated(
  { document: 'posts/{postId}', region: 'us-central1' },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const post = snapshot.data();
    const authorId = post.authorId;
    const postId = event.params.postId;

    // Skip if no author
    if (!authorId) return;

    // Get author info
    const authorDoc = await db.collection('users').doc(authorId).get();
    if (!authorDoc.exists) return;
    const authorData = authorDoc.data();
    const authorName = authorData.firstName || authorData.username || 'Someone';

    // Get all followers of this author (people who follow the author)
    const followersSnap = await db.collection('follows')
      .where('followingId', '==', authorId)
      .get();

    if (followersSnap.empty) {
      logger.info('No followers to notify', { authorId });
      return;
    }

    // Get post preview
    let postPreview = post.content || post.text || '';
    if (postPreview.length > 80) {
      postPreview = postPreview.substring(0, 80) + '...';
    }
    if (!postPreview && post.mediaUrls && post.mediaUrls.length > 0) {
      postPreview = 'shared a photo';
    }

    // Send push to each follower (batch to avoid overwhelming)
    const followerIds = followersSnap.docs.map(doc => doc.data().followerId);
    
    // Limit to first 100 followers to avoid function timeout
    const limitedFollowers = followerIds.slice(0, 100);

    for (const followerId of limitedFollowers) {
      // Check if follower has muted author
      const muteCheck = await db.collection('mutes')
        .where('mutedByUid', '==', followerId)
        .where('mutedUid', '==', authorId)
        .limit(1)
        .get();
      
      if (muteCheck.empty) {
        await sendPushToUser(
          followerId,
          `${authorName} posted`,
          postPreview || 'shared a new post',
          { type: 'post', postId, authorId }
        );
      }
    }

    logger.info('Post notifications sent', { postId, followerCount: limitedFollowers.length });
  }
);

// 5. PUSH FOR INVITATIONS
exports.onInvitationCreated = onDocumentCreated(
  { document: 'invitations/{invitationId}', region: 'us-central1' },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const invitation = snapshot.data();
    const senderId = invitation.senderId || invitation.fromUserId;
    const recipientId = invitation.recipientId || invitation.toUserId;

    if (!senderId || !recipientId) return;

    // Get sender name
    const senderDoc = await db.collection('users').doc(senderId).get();
    const senderName = senderDoc.exists ? 
      (senderDoc.data().firstName || senderDoc.data().username || 'Someone') : 'Someone';

    await sendPushToUser(
      recipientId,
      'New Invitation',
      `${senderName} sent you an invitation`,
      { type: 'invitation', invitationId: event.params.invitationId, senderId }
    );
  }
);
