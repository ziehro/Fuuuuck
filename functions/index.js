const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

exports.aggregateContribution = onDocumentCreated(
  "contributions/{contributionId}",
  async (event) => {
    const contribution = event.data.data();
    const beachRef = getFirestore()
      .collection("beaches")
      .doc(contribution.beachId);

    const updates = {
      totalContributions: admin.firestore.FieldValue.increment(1),
      lastAggregated: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (contribution.userAnswers && contribution.userAnswers["Short Description"]) {
      updates.contributedDescriptions = admin.firestore.FieldValue.arrayUnion(
        contribution.userAnswers["Short Description"]
      );
    }

    return beachRef.update(updates);
  }
);