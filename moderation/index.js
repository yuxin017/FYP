const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {LanguageServiceClient} = require("@google-cloud/language").v1;

admin.initializeApp();

const languageClient = new LanguageServiceClient();

// Categories that should block a public travel review.
// Threshold can be adjusted after testing.
const BLOCK_THRESHOLDS = {
  "Toxic": 0.7,
  "Derogatory": 0.7,
  "Violent": 0.8,
  "Sexual": 0.8,
  "Insult": 0.75,
  "Profanity": 0.7,
  "Death, Harm & Tragedy": 0.9,
};

exports.moderateReview = onRequest(
    {
      region: "us-central1",
      timeoutSeconds: 30,
      memory: "256MiB",
      cors: true,
    },
    async (req, res) => {
      try {
        // =====================================================
        // 1. POST ONLY
        // =====================================================
        if (req.method !== "POST") {
          res.status(405).json({
            allowed: false,
            message: "Method not allowed.",
            source: "function",
          });
          return;
        }

        // =====================================================
        // 2. VERIFY FIREBASE LOGIN
        // =====================================================
        const authorization =
          req.headers.authorization || "";

        if (!authorization.startsWith("Bearer ")) {
          res.status(401).json({
            allowed: false,
            message:
              "Please login before submitting a review.",
            source: "authentication",
          });
          return;
        }

        const idToken =
          authorization.substring("Bearer ".length);

        try {
          await admin.auth().verifyIdToken(idToken);
        } catch (error) {
          console.error(
              "Firebase token verification failed:",
              error,
          );

          res.status(401).json({
            allowed: false,
            message:
              "Your session has expired. Please login again.",
            source: "authentication",
          });
          return;
        }

        // =====================================================
        // 3. GET REVIEW TEXT
        // =====================================================
        const text = String(
            req.body && req.body.text ?
              req.body.text :
              "",
        ).trim();

        // Review text is OPTIONAL.
        if (text.length === 0) {
          res.status(200).json({
            allowed: true,
            message: "No review text to moderate.",
            source: "validation",
          });
          return;
        }

        if (text.length > 800) {
          res.status(400).json({
            allowed: false,
            message:
              "Review must be 800 characters or fewer.",
            source: "validation",
          });
          return;
        }

        // =====================================================
        // 4. GOOGLE CLOUD NATURAL LANGUAGE MODERATION
        // =====================================================
        const request = {
          document: {
            type: "PLAIN_TEXT",
            content: text,
          },
        };

        const [response] =
          await languageClient.moderateText(request);

        const categories =
          response.moderationCategories || [];

        console.log(
            "Google moderation result:",
            JSON.stringify(categories),
        );

        // =====================================================
        // 5. CHECK MODERATION SCORES
        // =====================================================
        const blockedCategories = [];

        for (const category of categories) {
          const name =
            String(category.name || "");

          const confidence =
            Number(category.confidence || 0);

          const threshold =
            BLOCK_THRESHOLDS[name];

          if (
            threshold !== undefined &&
            confidence >= threshold
          ) {
            blockedCategories.push({
              name: name,
              confidence: confidence,
            });
          }
        }

        // =====================================================
        // 6. BLOCK INAPPROPRIATE REVIEW
        // =====================================================
        if (blockedCategories.length > 0) {
          console.log(
              "Review rejected:",
              JSON.stringify(blockedCategories),
          );

          res.status(200).json({
            allowed: false,
            message:
              "Your review contains inappropriate content. " +
              "Please revise it before submitting.",
            source: "google-moderation",
          });
          return;
        }

        // =====================================================
        // 7. REVIEW PASSED
        // =====================================================
        res.status(200).json({
          allowed: true,
          message:
            "Review passed content checks.",
          source: "google-moderation",
        });
      } catch (error) {
        console.error(
            "Google moderation error:",
            error,
        );

        res.status(500).json({
          allowed: false,
          message:
            "Unable to check review content right now. " +
            "Please try again.",
          source: "server",
        });
      }
    },
);
