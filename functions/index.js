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
          const currentMetricValue = beachData.aggregatedMetrics[key] || 0;
          const newAverage = ((currentMetricValue * oldTotalContributions) + newValue) / newTotalContributions;
          updates[`aggregatedMetrics.${key}`] = newAverage;
        } else if (typeof newValue === 'string' && newValue.length > 0) {
          updates[`aggregatedSingleChoices.${key}.${newValue}`] = FieldValue.increment(1);
        } else if (Array.isArray(newValue)) {
            // **THIS IS THE FIX:**
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

      if (contribution.contributedImageUrls && contribution.contributedImageUrls.length > 0) {
        updates.imageUrls = FieldValue.arrayUnion(...contribution.contributedImageUrls);
      }
      if (userAnswers["Short Description"]) {
        updates.contributedDescriptions = FieldValue.arrayUnion(userAnswers["Short Description"]);
      }

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