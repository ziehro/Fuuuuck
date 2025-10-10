// functions/index.js
// Beach Book Cloud Functions

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

// ========================================
// CONTRIBUTION AGGREGATION
// ========================================
// This function runs whenever a new contribution is added to a beach
// It updates the beach's aggregated data (averages, counts, etc.)
exports.aggregateContribution = onDocumentCreated(
  "beaches/{beachId}/contributions/{contributionId}",
  async (event) => {
    const contribution = event.data.data();
    const beachId = event.params.beachId;
    const beachRef = getFirestore().collection("beaches").doc(beachId);

    return getFirestore().runTransaction(async (transaction) => {
      const beachDoc = await transaction.get(beachRef);
      if (!beachDoc.exists) {
        throw `Beach document with ID ${beachId} does not exist.`;
      }

      const beachData = beachDoc.data();
      const oldTotalContributions = beachData.totalContributions || 0;
      const newTotalContributions = oldTotalContributions + 1;

      const updates = {
        totalContributions: newTotalContributions,
        lastAggregated: FieldValue.serverTimestamp(),
      };

      const userAnswers = contribution.userAnswers || {};

      // Define all keys that are text fields and should be aggregated as text arrays.
      const textArrayKeys = ["Birds", "Tree types", "Treasure", "New Items"];

      for (const key in userAnswers) {
        const newValue = userAnswers[key];

        // Skip fields that shouldn't be aggregated directly here
        if (["Beach Name", "Short Description", "Country", "Province", "Municipality"].includes(key)) {
          continue;
        }

        if (typeof newValue === 'number') {
          // Handle numeric values (sliders) - calculate running average
          const currentMetricValue = beachData.aggregatedMetrics?.[key] || 0;
          const newAverage = ((currentMetricValue * oldTotalContributions) + newValue) / newTotalContributions;
          updates[`aggregatedMetrics.${key}`] = newAverage;
        } else if (typeof newValue === 'string' && newValue.length > 0) {
          // Handle single choice selections - increment count
          updates[`aggregatedSingleChoices.${key}.${newValue}`] = FieldValue.increment(1);
        } else if (Array.isArray(newValue)) {
          // **IMPORTANT FIX:**
          // First, check if the key is one of our special text array fields.
          if (textArrayKeys.includes(key)) {
            if (newValue.length > 0) {
              updates[`aggregatedTextItems.${key}`] = FieldValue.arrayUnion(...newValue);
            }
          }
          // If it's not a text array, THEN treat it as a multi-choice array.
          else if (newValue.every(item => typeof item === 'string')) {
            newValue.forEach(option => {
              updates[`aggregatedMultiChoices.${key}.${option}`] = FieldValue.increment(1);
            });
          }
        }
      }

      // Handle contributed images
      if (contribution.contributedImageUrls && contribution.contributedImageUrls.length > 0) {
        updates.imageUrls = FieldValue.arrayUnion(...contribution.contributedImageUrls);
      }

      // Handle short descriptions
      if (userAnswers["Short Description"]) {
        updates.contributedDescriptions = FieldValue.arrayUnion(userAnswers["Short Description"]);
      }

      // Handle AI-confirmed flora/fauna identifications
      if (contribution.aiConfirmedFloraFauna) {
        for (const item of contribution.aiConfirmedFloraFauna) {
          updates[`identifiedFloraFauna.${item.commonName}.count`] = FieldValue.increment(1);
          updates[`identifiedFloraFauna.${item.commonName}.taxonId`] = item.taxonId;
          updates[`identifiedFloraFauna.${item.commonName}.imageUrl`] = item.imageUrl;
        }
      }

      transaction.update(beachRef, updates);
    });
  }
);

// ========================================
// MODERATION NOTIFICATIONS
// ========================================
// These functions notify you when new content needs approval

// Notify admin when a new beach is submitted for approval
exports.notifyNewPendingBeach = onDocumentCreated(
  "pending_beaches/{beachId}",
  async (event) => {
    const beach = event.data.data();
    const beachId = event.params.beachId;

    console.log("════════════════════════════════════════════════");
    console.log("📬 NEW PENDING BEACH SUBMITTED");
    console.log("════════════════════════════════════════════════");
    console.log(`🏖️  Beach Name: ${beach.name}`);
    console.log(`📍 Location: ${beach.municipality}, ${beach.province}, ${beach.country}`);
    console.log(`👤 Submitted by: ${beach.submittedBy}`);
    console.log(`🕒 Submitted at: ${beach.submittedAt?.toDate().toLocaleString()}`);
    console.log(`🔗 Beach ID: ${beachId}`);
    console.log("════════════════════════════════════════════════");

    // TODO: Send email/push notification to admin
    // You can integrate with SendGrid, Firebase Cloud Messaging, or other services

    // Example SendGrid integration (uncomment and configure):
    /*
    const sgMail = require('@sendgrid/mail');
    sgMail.setApiKey(process.env.SENDGRID_API_KEY);

    const msg = {
      to: 'your-email@example.com',
      from: 'beachbook@yourapp.com',
      subject: '🏖️ New Beach Pending Approval',
      text: `Beach "${beach.name}" has been submitted by ${beach.submittedBy}`,
      html: `
        <h2>New Beach Pending Approval</h2>
        <p><strong>Beach Name:</strong> ${beach.name}</p>
        <p><strong>Location:</strong> ${beach.municipality}, ${beach.province}</p>
        <p><strong>Submitted by:</strong> ${beach.submittedBy}</p>
        <p><strong>Description:</strong> ${beach.description}</p>
        <p><a href="https://console.firebase.google.com/project/YOUR_PROJECT/firestore/data/~2Fpending_beaches~2F${beachId}">View in Firebase Console</a></p>
      `,
    };

    await sgMail.send(msg);
    */

    return { success: true, message: "Notification logged" };
  }
);

// Notify admin when a new contribution is submitted for approval
exports.notifyNewPendingContribution = onDocumentCreated(
  "beaches/{beachId}/pending_contributions/{contributionId}",
  async (event) => {
    const contribution = event.data.data();
    const beachId = event.params.beachId;
    const contributionId = event.params.contributionId;

    // Get beach name for better notification
    const beachDoc = await getFirestore()
      .collection("beaches")
      .doc(beachId)
      .get();
    const beachName = beachDoc.exists ? beachDoc.data().name : "Unknown Beach";

    console.log("════════════════════════════════════════════════");
    console.log("📬 NEW PENDING CONTRIBUTION SUBMITTED");
    console.log("════════════════════════════════════════════════");
    console.log(`🏖️  Beach: ${beachName}`);
    console.log(`👤 Submitted by: ${contribution.userEmail}`);
    console.log(`🕒 Submitted at: ${contribution.timestamp?.toDate().toLocaleString()}`);
    console.log(`📸 Images: ${contribution.contributedImageUrls?.length || 0}`);
    console.log(`🔗 Beach ID: ${beachId}`);
    console.log(`🔗 Contribution ID: ${contributionId}`);
    console.log("════════════════════════════════════════════════");

    // TODO: Send email/push notification to admin

    // Example SendGrid integration:
    /*
    const sgMail = require('@sendgrid/mail');
    sgMail.setApiKey(process.env.SENDGRID_API_KEY);

    const msg = {
      to: 'your-email@example.com',
      from: 'beachbook@yourapp.com',
      subject: '📝 New Contribution Pending Approval',
      text: `New contribution to "${beachName}" by ${contribution.userEmail}`,
      html: `
        <h2>New Contribution Pending Approval</h2>
        <p><strong>Beach:</strong> ${beachName}</p>
        <p><strong>Submitted by:</strong> ${contribution.userEmail}</p>
        <p><strong>Images:</strong> ${contribution.contributedImageUrls?.length || 0}</p>
        <p><a href="https://console.firebase.google.com/project/YOUR_PROJECT/firestore/data/~2Fbeaches~2F${beachId}~2Fpending_contributions~2F${contributionId}">View in Firebase Console</a></p>
      `,
    };

    await sgMail.send(msg);
    */

    return { success: true, message: "Notification logged" };
  }
);

// ========================================
// USER NOTIFICATIONS (Optional)
// ========================================
// Notify users when their submissions are approved

// Notify user when their beach is approved
exports.notifyUserBeachApproved = onDocumentCreated(
  "beaches/{beachId}",
  async (event) => {
    const beach = event.data.data();
    const beachId = event.params.beachId;

    // Check if this was recently submitted (within last hour)
    // This prevents notifications for old beaches or migrations
    const now = Date.now();
    const submittedAt = beach.timestamp?.toMillis();

    if (submittedAt && (now - submittedAt) < 3600000) { // Within 1 hour
      console.log("════════════════════════════════════════════════");
      console.log("✅ BEACH APPROVED");
      console.log("════════════════════════════════════════════════");
      console.log(`🏖️  Beach: ${beach.name}`);
      console.log(`🔗 Beach ID: ${beachId}`);
      console.log("════════════════════════════════════════════════");

      // TODO: Send approval notification to user
      // You could look up the user's email from the initial contribution
      // and send them a "Your beach has been approved!" email
    }

    return { success: true };
  }
);

// Notify user when their contribution is approved
exports.notifyUserContributionApproved = onDocumentCreated(
  "beaches/{beachId}/contributions/{contributionId}",
  async (event) => {
    const contribution = event.data.data();
    const contributionId = event.params.contributionId;
    const beachId = event.params.beachId;

    // Check if this was recently pending (submitted within last hour)
    const now = Date.now();
    const submittedAt = contribution.timestamp?.toMillis();

    if (submittedAt && (now - submittedAt) < 3600000) { // Within 1 hour
      // Get beach name
      const beachDoc = await getFirestore()
        .collection("beaches")
        .doc(beachId)
        .get();
      const beachName = beachDoc.exists ? beachDoc.data().name : "a beach";

      console.log("════════════════════════════════════════════════");
      console.log("✅ CONTRIBUTION APPROVED");
      console.log("════════════════════════════════════════════════");
      console.log(`🏖️  Beach: ${beachName}`);
      console.log(`👤 User: ${contribution.userEmail}`);
      console.log(`🔗 Contribution ID: ${contributionId}`);
      console.log("════════════════════════════════════════════════");

      // TODO: Send approval notification to user
      /*
      const sgMail = require('@sendgrid/mail');
      sgMail.setApiKey(process.env.SENDGRID_API_KEY);

      const msg = {
        to: contribution.userEmail,
        from: 'beachbook@yourapp.com',
        subject: '✅ Your Contribution Has Been Approved!',
        text: `Your contribution to "${beachName}" has been approved and is now visible to everyone!`,
        html: `
          <h2>Contribution Approved! 🎉</h2>
          <p>Your contribution to <strong>${beachName}</strong> has been approved and is now visible to everyone!</p>
          <p>Thank you for contributing to Beach Book!</p>
        `,
      };

      await sgMail.send(msg);
      */
    }

    return { success: true };
  }
);

// ========================================
// STATISTICS TRACKING (Optional)
// ========================================
// Track moderation statistics

exports.trackModerationStats = onDocumentCreated(
  "beaches/{beachId}",
  async (event) => {
    const beachId = event.params.beachId;
    const beach = event.data.data();

    // Update global statistics
    const statsRef = getFirestore().collection("app_statistics").doc("moderation");

    await statsRef.set({
      totalBeachesApproved: FieldValue.increment(1),
      lastApprovalTime: FieldValue.serverTimestamp(),
      lastApprovedBeach: {
        id: beachId,
        name: beach.name,
        location: `${beach.municipality}, ${beach.province}`,
      }
    }, { merge: true });

    return { success: true };
  }
);

// ========================================
// CLEANUP FUNCTIONS (Optional)
// ========================================
// Clean up old rejected submissions after 30 days

// Note: This would need to be scheduled using Cloud Scheduler
// exports.cleanupOldRejections = onSchedule("every 24 hours", async (event) => {
//   const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
//
//   // Clean up old pending beaches
//   const oldPendingBeaches = await getFirestore()
//     .collection("pending_beaches")
//     .where("submittedAt", "<", thirtyDaysAgo)
//     .get();
//
//   const batch = getFirestore().batch();
//   oldPendingBeaches.docs.forEach((doc) => {
//     batch.delete(doc.ref);
//   });
//
//   await batch.commit();
//   console.log(`Cleaned up ${oldPendingBeaches.size} old pending beaches`);
// });