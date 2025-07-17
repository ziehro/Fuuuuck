// ziehro/fuuuuck/ziehro-Fuuuuck-b2274051aa8ffd19a9b4cf34cac1a996c65c1899/functions/index.js
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
        throw "Beach document does not exist!";
      }

      const beachData = beachDoc.data();
      const totalContributions = beachData.totalContributions + 1;

      const updates = {
        totalContributions: totalContributions,
        lastAggregated: FieldValue.serverTimestamp(),
      };

      // Amalgamate Metrics (Sliders and Numbers)
      const newMetrics = {};
      for (const key in contribution.userAnswers) {
        if (typeof contribution.userAnswers[key] === 'number') {
          const currentMetric = beachData.aggregatedMetrics[key] || 0;
          const newAverage = ((currentMetric * (totalContributions - 1)) + contribution.userAnswers[key]) / totalContributions;
          newMetrics[`aggregatedMetrics.${key}`] = newAverage;
        }
      }
      Object.assign(updates, newMetrics);

      // Amalgamate Single Choices (simple overwrite with latest, but can be improved)
      const newSingleChoices = {};
      for (const key in contribution.userAnswers) {
        if (typeof contribution.userAnswers[key] === 'string') {
            newSingleChoices[`aggregatedSingleChoices.${key}`] = contribution.userAnswers[key];
        }
      }
      Object.assign(updates, newSingleChoices);


      // Amalgamate Multi-Choices (union of all chosen options)
        const newMultiChoices = {};
        for (const key in contribution.userAnswers) {
            if (Array.isArray(contribution.userAnswers[key])) {
                newMultiChoices[`aggregatedMultiChoices.${key}`] = FieldValue.arrayUnion(...contribution.userAnswers[key]);
            }
        }
        Object.assign(updates, newMultiChoices);


      // Amalgamate Text Items
      const newTextItems = {};
        for (const key in contribution.userAnswers) {
            if (Array.isArray(contribution.userAnswers[key])) {
                newTextItems[`aggregatedTextItems.${key}`] = FieldValue.arrayUnion(...contribution.userAnswers[key]);
            }
        }
        Object.assign(updates, newTextItems);

      // Amalgamate Flora/Fauna Counts
      if (contribution.aiConfirmedFloraFauna) {
        const newFloraFauna = {};
        for (const item of contribution.aiConfirmedFloraFauna) {
          newFloraFauna[`identifiedFloraFaunaCounts.${item.commonName}`] = FieldValue.increment(1);
        }
        Object.assign(updates, newFloraFauna);
      }

      // Amalgamate Contributed Descriptions
      if (contribution.userAnswers && contribution.userAnswers["Short Description"]) {
        updates.contributedDescriptions = FieldValue.arrayUnion(contribution.userAnswers["Short Description"]);
      }

      // Amalgamate Image URLs
        if (contribution.contributedImageUrls) {
            updates.imageUrls = FieldValue.arrayUnion(...contribution.contributedImageUrls);
        }


      transaction.update(beachRef, updates);
    });
  }
);