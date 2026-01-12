const { onDocumentWritten, onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Like counter: increment on create, decrement on delete
exports.likeCounter = onDocumentWritten({ region: "us-central1", document: "posts/{postId}/likes/{uid}" }, async (event) => {
  try {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    let inc = 0;
    if (!before && after) inc = 1;        // created
    else if (before && !after) inc = -1;  // deleted
    else return;                          // updated/no-op

    await admin
      .firestore()
      .doc(`posts/${event.params.postId}`)
      .update({ "summary.likes": admin.firestore.FieldValue.increment(inc) });
  } catch (err) {
    logger.error("likeCounter failed", { error: err?.message || String(err), params: event.params });
  }
});

// Bookmark counter: increment on create, decrement on delete
exports.bookmarkCounter = onDocumentWritten({ region: "us-central1", document: "posts/{postId}/bookmarks/{uid}" }, async (event) => {
  try {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    let inc = 0;
    if (!before && after) inc = 1;        // created
    else if (before && !after) inc = -1;  // deleted
    else return;                          // updated/no-op

    await admin
      .firestore()
      .doc(`posts/${event.params.postId}`)
      .update({ "summary.bookmarks": admin.firestore.FieldValue.increment(inc) });
  } catch (err) {
    logger.error("bookmarkCounter failed", { error: err?.message || String(err), params: event.params });
  }
});

// Repost counter: increment when a repost is created
exports.repostCounterOnCreate = onDocumentCreated({ region: "us-central1", document: "posts/{postId}" }, async (event) => {
  try {
    const data = event.data?.data();
    const repostOf = data?.repostOf;
    if (!repostOf) return;
    await admin
      .firestore()
      .doc(`posts/${repostOf}`)
      .update({ "summary.reposts": admin.firestore.FieldValue.increment(1) });
  } catch (err) {
    logger.error("repostCounterOnCreate failed", { error: err?.message || String(err), params: event.params });
  }
});

// Repost counter: decrement when a repost is deleted
exports.repostCounterOnDelete = onDocumentDeleted({ region: "us-central1", document: "posts/{postId}" }, async (event) => {
  try {
    const data = event.data?.data();
    const repostOf = data?.repostOf;
    if (!repostOf) return;
    await admin
      .firestore()
      .doc(`posts/${repostOf}`)
      .update({ "summary.reposts": admin.firestore.FieldValue.increment(-1) });
  } catch (err) {
    logger.error("repostCounterOnDelete failed", { error: err?.message || String(err), params: event.params });
  }
});

// ============================================================
// NOTIFICATION TRIGGERS - Push notifications for all events
// ============================================================

// Helper: Send push notification to a user
async function sendPushNotification(userId, title, body, data = {}) {
  try {
    // Get user's FCM tokens
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) return;
    
    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];
    
    if (fcmTokens.length === 0) {
      logger.info("No FCM tokens for user", { userId });
      return;
    }
    
    // Create notification in Firestore
    await admin.firestore().collection('users').doc(userId).collection('notifications').add({
      userId,
      type: data.type || 'system',
      title,
      body,
      data,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Send push notification
    const message = {
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      tokens: fcmTokens,
    };
    
    const response = await admin.messaging().sendEachForMulticast(message);
    logger.info("Push notification sent", { userId, successCount: response.successCount });
    
    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error?.code === 'messaging/registration-token-not-registered') {
          invalidTokens.push(fcmTokens[idx]);
        }
      });
      if (invalidTokens.length > 0) {
        await admin.firestore().collection('users').doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens)
        });
      }
    }
  } catch (err) {
    logger.error("sendPushNotification failed", { error: err?.message || String(err), userId });
  }
}

// Helper: Get user display name
async function getUserDisplayName(userId) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) return 'Someone';
    const data = userDoc.data();
    return data.displayName || data.username || data.firstName || 'Someone';
  } catch {
    return 'Someone';
  }
}

// 1. Like on Post notification
exports.notifyOnPostLike = onDocumentCreated({ region: "us-central1", document: "posts/{postId}/likes/{likerId}" }, async (event) => {
  try {
    const postId = event.params.postId;
    const likerId = event.params.likerId;
    
    // Get post to find author
    const postDoc = await admin.firestore().collection('posts').doc(postId).get();
    if (!postDoc.exists) return;
    
    const postData = postDoc.data();
    const authorId = postData.authorId;
    
    // Don't notify if user liked their own post
    if (authorId === likerId) return;
    
    const likerName = await getUserDisplayName(likerId);
    
    await sendPushNotification(authorId, 'New Like', `${likerName} liked your post`, {
      type: 'like',
      postId,
      fromUserId: likerId,
    });
  } catch (err) {
    logger.error("notifyOnPostLike failed", { error: err?.message || String(err) });
  }
});

// 2. Comment on Post notification
exports.notifyOnComment = onDocumentCreated({ region: "us-central1", document: "posts/{postId}/comments/{commentId}" }, async (event) => {
  try {
    const postId = event.params.postId;
    const commentData = event.data?.data();
    if (!commentData) return;
    
    const commenterId = commentData.authorId;
    
    // Get post to find author
    const postDoc = await admin.firestore().collection('posts').doc(postId).get();
    if (!postDoc.exists) return;
    
    const postData = postDoc.data();
    const postAuthorId = postData.authorId;
    
    // Don't notify if user commented on their own post
    if (postAuthorId === commenterId) return;
    
    const commenterName = await getUserDisplayName(commenterId);
    const commentPreview = (commentData.text || '').substring(0, 50);
    
    await sendPushNotification(postAuthorId, 'New Comment', `${commenterName}: ${commentPreview}`, {
      type: 'comment',
      postId,
      fromUserId: commenterId,
    });
    
    // 3. Reply to Comment notification - if this is a reply
    if (commentData.parentId) {
      const parentCommentDoc = await admin.firestore()
        .collection('posts').doc(postId)
        .collection('comments').doc(commentData.parentId).get();
      
      if (parentCommentDoc.exists) {
        const parentData = parentCommentDoc.data();
        const parentAuthorId = parentData.authorId;
        
        // Don't notify if replying to own comment
        if (parentAuthorId !== commenterId && parentAuthorId !== postAuthorId) {
          await sendPushNotification(parentAuthorId, 'New Reply', `${commenterName} replied: ${commentPreview}`, {
            type: 'comment_reply',
            postId,
            fromUserId: commenterId,
          });
        }
      }
    }
  } catch (err) {
    logger.error("notifyOnComment failed", { error: err?.message || String(err) });
  }
});

// 4. Like on Comment notification
exports.notifyOnCommentLike = onDocumentCreated({ region: "us-central1", document: "posts/{postId}/comments/{commentId}/likes/{likerId}" }, async (event) => {
  try {
    const postId = event.params.postId;
    const commentId = event.params.commentId;
    const likerId = event.params.likerId;
    
    // Get comment to find author
    const commentDoc = await admin.firestore()
      .collection('posts').doc(postId)
      .collection('comments').doc(commentId).get();
    if (!commentDoc.exists) return;
    
    const commentData = commentDoc.data();
    const commentAuthorId = commentData.authorId;
    
    // Don't notify if user liked their own comment
    if (commentAuthorId === likerId) return;
    
    const likerName = await getUserDisplayName(likerId);
    
    await sendPushNotification(commentAuthorId, 'Comment Liked', `${likerName} liked your comment`, {
      type: 'like_on_comment',
      postId,
      fromUserId: likerId,
    });
  } catch (err) {
    logger.error("notifyOnCommentLike failed", { error: err?.message || String(err) });
  }
});

// 5. New Connection notification
exports.notifyOnNewConnection = onDocumentCreated({ region: "us-central1", document: "follows/{followId}" }, async (event) => {
  try {
    const followData = event.data?.data();
    if (!followData) return;
    
    const followerId = followData.followerId;
    const followedId = followData.followedId;
    
    const followerName = await getUserDisplayName(followerId);
    
    // Check if this creates a mutual connection
    const reverseFollow = await admin.firestore().collection('follows')
      .where('followerId', '==', followedId)
      .where('followedId', '==', followerId)
      .limit(1).get();
    
    if (!reverseFollow.empty) {
      // Mutual connection - notify both
      const followedName = await getUserDisplayName(followedId);
      
      await sendPushNotification(followerId, 'New Connection', `You and ${followedName} are now connected!`, {
        type: 'new_connection',
        fromUserId: followedId,
      });
      
      await sendPushNotification(followedId, 'New Connection', `You and ${followerName} are now connected!`, {
        type: 'new_connection',
        fromUserId: followerId,
      });
    } else {
      // Just a follow
      await sendPushNotification(followedId, 'New Follower', `${followerName} started following you`, {
        type: 'follow',
        fromUserId: followerId,
      });
    }
  } catch (err) {
    logger.error("notifyOnNewConnection failed", { error: err?.message || String(err) });
  }
});

// 6. Invitation Received notification
exports.notifyOnInvitationReceived = onDocumentCreated({ region: "us-central1", document: "invitations/{invitationId}" }, async (event) => {
  try {
    const invitationData = event.data?.data();
    if (!invitationData) return;
    
    const fromUserId = invitationData.fromUserId;
    const toUserId = invitationData.toUserId;
    
    const senderName = await getUserDisplayName(fromUserId);
    const message = invitationData.message ? `: "${invitationData.message.substring(0, 50)}"` : '';
    
    await sendPushNotification(toUserId, 'New Invitation', `${senderName} sent you an invitation${message}`, {
      type: 'invitation_received',
      invitationId: event.params.invitationId,
      fromUserId,
    });
  } catch (err) {
    logger.error("notifyOnInvitationReceived failed", { error: err?.message || String(err) });
  }
});

// 7. Invitation Accepted notification
exports.notifyOnInvitationAccepted = onDocumentWritten({ region: "us-central1", document: "invitations/{invitationId}" }, async (event) => {
  try {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    
    // Only trigger when status changes to 'accepted'
    if (!before || !after) return;
    if (before.status === 'accepted' || after.status !== 'accepted') return;
    
    const fromUserId = after.fromUserId;
    const toUserId = after.toUserId;
    
    const accepterName = await getUserDisplayName(toUserId);
    
    await sendPushNotification(fromUserId, 'Invitation Accepted', `${accepterName} accepted your invitation!`, {
      type: 'invitation_accepted',
      invitationId: event.params.invitationId,
      fromUserId: toUserId,
      conversationId: after.conversationId,
    });
  } catch (err) {
    logger.error("notifyOnInvitationAccepted failed", { error: err?.message || String(err) });
  }
});

// 8. New Podcast notification (to followers)
exports.notifyOnNewPodcast = onDocumentCreated({ region: "us-central1", document: "podcasts/{podcastId}" }, async (event) => {
  try {
    const podcastData = event.data?.data();
    if (!podcastData) return;
    
    const authorId = podcastData.authorId;
    const podcastTitle = podcastData.title || 'New Podcast';
    const authorName = await getUserDisplayName(authorId);
    
    // Get all followers of the author
    const followersSnapshot = await admin.firestore().collection('follows')
      .where('followedId', '==', authorId)
      .get();
    
    // Notify each follower (batch to avoid rate limits)
    const notifications = followersSnapshot.docs.map(doc => {
      const followerId = doc.data().followerId;
      return sendPushNotification(followerId, 'New Podcast', `${authorName} published: ${podcastTitle}`, {
        type: 'new_podcast',
        podcastId: event.params.podcastId,
        fromUserId: authorId,
      });
    });
    
    await Promise.all(notifications);
    logger.info("Notified followers of new podcast", { podcastId: event.params.podcastId, count: notifications.length });
  } catch (err) {
    logger.error("notifyOnNewPodcast failed", { error: err?.message || String(err) });
  }
});

// 9. New Book notification (to followers)
exports.notifyOnNewBook = onDocumentCreated({ region: "us-central1", document: "books/{bookId}" }, async (event) => {
  try {
    const bookData = event.data?.data();
    if (!bookData) return;
    
    const authorId = bookData.authorId;
    if (!authorId) return; // Skip if no author
    
    const bookTitle = bookData.title || 'New Book';
    const authorName = await getUserDisplayName(authorId);
    
    // Get all followers of the author
    const followersSnapshot = await admin.firestore().collection('follows')
      .where('followedId', '==', authorId)
      .get();
    
    // Notify each follower
    const notifications = followersSnapshot.docs.map(doc => {
      const followerId = doc.data().followerId;
      return sendPushNotification(followerId, 'New Book', `${authorName} published: ${bookTitle}`, {
        type: 'new_book',
        bookId: event.params.bookId,
        fromUserId: authorId,
      });
    });
    
    await Promise.all(notifications);
    logger.info("Notified followers of new book", { bookId: event.params.bookId, count: notifications.length });
  } catch (err) {
    logger.error("notifyOnNewBook failed", { error: err?.message || String(err) });
  }
});

// 10. Added to Group notification
exports.notifyOnAddedToGroup = onDocumentWritten({ region: "us-central1", document: "group_chats/{groupId}" }, async (event) => {
  try {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    
    if (!after) return; // Deleted
    
    const beforeMembers = new Set(before?.memberIds || []);
    const afterMembers = new Set(after.memberIds || []);
    
    // Find newly added members
    const newMembers = [...afterMembers].filter(id => !beforeMembers.has(id));
    
    if (newMembers.length === 0) return;
    
    const groupName = after.name || 'a group';
    
    // Notify each new member
    const notifications = newMembers.map(memberId => {
      return sendPushNotification(memberId, 'Added to Group', `You were added to ${groupName}`, {
        type: 'added_to_group',
        groupId: event.params.groupId,
      });
    });
    
    await Promise.all(notifications);
    logger.info("Notified new group members", { groupId: event.params.groupId, count: newMembers.length });
  } catch (err) {
    logger.error("notifyOnAddedToGroup failed", { error: err?.message || String(err) });
  }
});
