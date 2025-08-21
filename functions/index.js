// functions/index.js

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();


exports.sendChatNotification = functions.firestore
    .document("chat_rooms/{chatRoomId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
      const messageData = snapshot.data();

      const senderId = messageData.senderId;
      const receiverId = messageData.receiverId;
      const senderEmail = messageData.senderEmail;
      const messageText = messageData.text;

      if (!receiverId) {
        console.log("Receiver ID is missing. Cannot send notification.");
        return null;
      }

      if (senderId === receiverId) {
        console.log("Sender is the same as receiver. No notification needed.");
        return null;
      }

      // eslint-disable-next-line max-len
      const receiverDocRef = admin.firestore().collection("users").doc(receiverId);
      const receiverDoc = await receiverDocRef.get();

      if (!receiverDoc.exists) {
        console.log("Receiver user document not found:", receiverId);
        return null;
      }

      const fcmToken = receiverDoc.data().fcmToken;

      if (!fcmToken) {
        console.log("Receiver FCM token not found for user:", receiverId);
        return null;
      }

      const payload = {
        token: fcmToken,
        notification: {
          title: `New message from ${senderEmail}`,
          body: messageText || "You received an image.",
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
        console.log("Sending notification to token:", fcmToken);
        const response = await admin.messaging().send(payload);
        console.log("Successfully sent notification:", response);
        return response;
      } catch (error) {
        console.error("Error sending notification:", error);
        return null;
      }
    });
    