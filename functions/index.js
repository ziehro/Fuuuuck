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

      // --- Amalgamate User Answers ---
      const userAnswers = contribution.userAnswers || {};
      for (const key in userAnswers) {
        const newValue = userAnswers[key];

        // Handle numeric metrics (averaging)
        if (typeof newValue === 'number') {
          const currentMetricValue = beachData.aggregatedMetrics[key] || 0;
          const newAverage = ((currentMetricValue * oldTotalContributions) + newValue) / newTotalContributions;
          updates[`aggregatedMetrics.${key}`] = newAverage;
        }

        // Handle single-choice answers (counting occurrences)
        else if (typeof newValue === 'string' && key !== 'Short Description') {
          updates[`aggregatedSingleChoices.${key}.${newValue}`] = FieldValue.increment(1);
        }

        // Handle multi-choice answers (counting occurrences)
        else if (Array.isArray(newValue) && newValue.every(item => typeof item === 'string')) {
          newValue.forEach(option => {
            updates[`aggregatedMultiChoices.${key}.${option}`] = FieldValue.increment(1);
          });
        }
      }

      // --- Update Array Fields Safely ---
      if (contribution.contributedImageUrls && contribution.contributedImageUrls.length > 0) {
        updates.imageUrls = FieldValue.arrayUnion(...contribution.contributedImageUrls);
      }
      if (userAnswers["Short Description"]) {
        updates.contributedDescriptions = FieldValue.arrayUnion(userAnswers["Short Description"]);
      }

      // --- Update Flora/Fauna Counts ---
      if (contribution.aiConfirmedFloraFauna) {
        for (const item of contribution.aiConfirmedFloraFauna) {
            updates[`identifiedFloraFauna.${item.commonName}.count`] = FieldValue.increment(1);
            updates[`identifiedFloraFauna.${item.commonName}.taxonId`] = item.taxonId;
            updates[`identifiedFloraFauna.${item.commonName}.imageUrl`] = item.imageUrl;
        }
      }

      // Commit all updates to the document
      transaction.update(beachRef, updates);
    });
  }
);