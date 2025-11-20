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
