// functions/index.js

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();


exports.sendNotificationOnMessage = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const senderId = message.senderId;
    const receiverId = message.receiverId;
    const messageText = message.text || "";

    console.log("📩 New message:", message);

    
    let senderEmail = "Unknown";
    try {
      const senderDoc = await db.collection("users").doc(senderId).get();
      if (senderDoc.exists) {
        senderEmail = senderDoc.data().email || "Unknown";
      }
    } catch (e) {
      console.error("❌ Error fetching sender info:", e);
    }

    
    const receiverDoc = await db.collection("users").doc(receiverId).get();
    if (!receiverDoc.exists) {
      console.log("⚠️ No such receiver:", receiverId);
      return null;
    }

    const fcmTokens = receiverDoc.data().fcmTokens || [];
    if (fcmTokens.length === 0) {
      console.log("⚠️ No FCM tokens for receiver:", receiverId);
      return null;
    }

    
    const payload = {
      notification: {
        title: `Message from ${senderEmail}`,
        body: messageText || "📷 Sent you an image",
      },
      data: {
        senderEmail: senderEmail,
        senderID: senderId,
        message_body: messageText || "Image",
      },
      android: {
        priority: "high",
        notification: {
          channel_id: "high_importance_channel",
        },
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: fcmTokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
      });
      console.log("✅ Notification sent:", response);
      return response;
    } catch (error) {
      console.error("❌ Error sending notification:", error);
      return null;
    }
  });
