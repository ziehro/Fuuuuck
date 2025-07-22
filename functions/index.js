// functions/index.js
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

exports.aggregateContribution = onDocumentCreated(
  "beaches/{beachId}/contributions/{contributionId}",
  async (event) => {
    const contribution = event.data.data();
    const beachId = event.params.beachId;
    const beachRef = getFirestore().collection("beaches").doc(beachId);

    // Use a transaction to atomically update the beach document
    return getFirestore().runTransaction(async (transaction) => {
      const beachDoc = await transaction.get(beachRef);
      if (!beachDoc.exists) {
        throw `Beach document with ID ${beachId} does not exist.`;
      }

      const beachData = beachDoc.data();
      const oldTotalContributions = beachData.totalContributions || 0;
      const newTotalContributions = oldTotalContributions + 1;

      // Start building the updates object
      const updates = {
        totalContributions: newTotalContributions,
        lastAggregated: FieldValue.serverTimestamp(),
      };

      // --- Amalgamate Aggregated Metrics ---
      const userAnswers = contribution.userAnswers || {};
      for (const key in userAnswers) {
        const newValue = userAnswers[key];
        if (typeof newValue === 'number') {
          const currentMetricValue = beachData.aggregatedMetrics[key] || 0;
          const newAverage = ((currentMetricValue * oldTotalContributions) + newValue) / newTotalContributions;
          updates[`aggregatedMetrics.${key}`] = newAverage;
        }
      }

      // --- Update Array Fields Safely ---
      // ** FIX: Only call arrayUnion if there are new images to add **
      if (contribution.contributedImageUrls && contribution.contributedImageUrls.length > 0) {
        updates.imageUrls = FieldValue.arrayUnion(...contribution.contributedImageUrls);
      }
      // ** FIX: Only call arrayUnion if a new description exists **
      if (userAnswers["Short Description"]) {
        updates.contributedDescriptions = FieldValue.arrayUnion(userAnswers["Short Description"]);
      }

      // --- Update Flora/Fauna Counts ---
      if (contribution.aiConfirmedFloraFauna) {
        for (const item of contribution.aiConfirmedFloraFauna) {
            // Use dot notation to safely increment the count for a specific species
            updates[`identifiedFloraFauna.${item.commonName}.count`] = FieldValue.increment(1);
            // Set the taxonId and imageUrl if they don't exist yet
            updates[`identifiedFloraFauna.${item.commonName}.taxonId`] = item.taxonId;
            updates[`identifiedFloraFauna.${item.commonName}.imageUrl`] = item.imageUrl;
        }
      }

      // Commit all updates to the document
      transaction.update(beachRef, updates);
    });
  }
);