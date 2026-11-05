const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {LanguageServiceClient} = require("@google-cloud/language");
const admin = require("firebase-admin");
const OpenAI = require("openai");
const crypto = require("crypto");

if (!admin.apps.length) {
  admin.initializeApp();
}

const languageClient = new LanguageServiceClient();

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

// ============================================================
// TEXT MODERATION
// ============================================================

// Only safety categories are blocked. Legitimate travel topics such as
// religion, health, politics, finance and legal information remain allowed.
const thresholds = {
  "Toxic": 0.60,
  "Derogatory": 0.60,
  "Insult": 0.65,
  "Profanity": 0.60,
  "Sexual": 0.70,
  "Violent": 0.75,
  "Death, Harm & Tragedy": 0.85,
  "Firearms & Weapons": 0.90,
  "Illicit Drugs": 0.85,
};

exports.moderateText = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 30,
      enforceAppCheck: false,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Please sign in before posting.",
        );
      }

      const text = request.data?.text;

      if (typeof text !== "string" || text.trim().length === 0) {
        throw new HttpsError(
            "invalid-argument",
            "Text must not be empty.",
        );
      }

      if (text.length > 5000) {
        throw new HttpsError(
            "invalid-argument",
            "Text is too long.",
        );
      }

      try {
        const [response] = await languageClient.moderateText({
          document: {
            type: "PLAIN_TEXT",
            content: text,
          },
        });

        const categories = response.moderationCategories ?? [];

        const blocked = categories
            .filter((category) =>
              thresholds[category.name] !== undefined &&
              Number(category.confidence ?? 0) >=
                  thresholds[category.name])
            .sort((a, b) =>
              Number(b.confidence) - Number(a.confidence));

        return {
          isFlagged: blocked.length > 0,
          reason: blocked[0]?.name ?? null,
        };
      } catch (error) {
        console.error(
            "Google moderation failed",
            error,
        );

        throw new HttpsError(
            "unavailable",
            "Text moderation is temporarily unavailable. Please try again.",
        );
      }
    },
);

// ============================================================
// GENERATE STAMP IMAGE
// ============================================================

exports.generateStampImage = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 120,
      memory: "1GiB",
      enforceAppCheck: false,
      secrets: [OPENAI_API_KEY],
    },
    async (request) => {
      // ========================================================
      // AUTH CHECK
      // ========================================================

      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Please sign in before generating a stamp.",
        );
      }

      const uid = request.auth.uid;

      // ========================================================
      // ADMIN ROLE CHECK
      // ========================================================

      const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw new HttpsError(
            "permission-denied",
            "User record not found.",
        );
      }

      const role = String(
          userDoc.data()?.role || "",
      ).trim().toLowerCase();

      if (role !== "admin") {
        throw new HttpsError(
            "permission-denied",
            "Only administrators can generate stamp images.",
        );
      }

      // ========================================================
      // INPUT
      // ========================================================

      const attractionId = String(
          request.data?.attractionId || "",
      ).trim();

      const attractionName = String(
          request.data?.attractionName || "",
      ).trim();

      if (!attractionId || !attractionName) {
        throw new HttpsError(
            "invalid-argument",
            "attractionId and attractionName are required.",
        );
      }

      // ========================================================
      // GET ATTRACTION DATA
      // ========================================================

      const attractionDoc = await admin
          .firestore()
          .collection("attractions")
          .doc(attractionId)
          .get();

      let city = "";
      let state = "";
      let description = "";

      if (attractionDoc.exists) {
        const data = attractionDoc.data() || {};

        city = String(
            data.city || "",
        ).trim();

        state = String(
            data.state || "",
        ).trim();

        description = String(
            data.description || "",
        ).trim();
      }

      if (description.length > 600) {
        description =
            description.substring(0, 600);
      }

      // ========================================================
      // STYLE PROMPT
      // ========================================================

      const prompt = `
Create one square collectible tourism postage stamp illustration.

ATTRACTION:
${attractionName}

LOCATION:
${city}${city && state ? ", " : ""}${state}

ATTRACTION DESCRIPTION:
${description || "A Malaysian tourism and heritage attraction."}

The image must belong to the same visual collection as existing
Malaysian heritage tourism stamps.

VISUAL STYLE:

- White postage stamp.
- Clearly visible scalloped / perforated stamp edges on all four sides.
- Square overall composition.
- Large rounded arch or rounded rectangular illustration area.
- Main attraction landmark placed prominently in the center.
- Clean flat vector illustration.
- Simplified architectural forms.
- Soft geometric shapes.
- Minimal shading.
- Smooth polished tourism-poster illustration.
- Warm and slightly muted colors.
- Elegant modern heritage-travel aesthetic.

COLOR PALETTE:

Use combinations of:
- warm cream
- ivory
- beige
- muted orange
- terracotta
- golden brown
- dark brown
- olive green
- soft green
- muted turquoise
- soft blue

COMPOSITION:

- Landmark illustration should occupy around 70 percent of the stamp.
- Keep the landmark centered.
- Use a pale cream or light neutral background behind the landmark.
- White area underneath the illustration for the attraction name.
- Balanced symmetrical layout.
- Clean margins.

TEXT:

At the bottom of the stamp write exactly:

"${attractionName}"

Use bold black clean sans-serif text.
Center the text horizontally.
If the name is long, split neatly into two lines.

Do not add any other text.

STRICTLY DO NOT INCLUDE:

- watermark
- AI logo
- branding
- signature
- random letters
- country name
- date
- badge
- QR code
- photograph
- realistic photography
- watercolor
- pencil sketch
- 3D render
- glossy 3D objects
- cartoon characters

The finished image should look like a polished,
coordinated collectible tourism stamp from the same series.
`.trim();

      // ========================================================
      // OPENAI
      // ========================================================

      try {
        const openai = new OpenAI({
          apiKey: OPENAI_API_KEY.value(),
        });

        const result = await openai.images.generate({
          model: "gpt-image-2",
          prompt: prompt,
          size: "1024x1024",
          quality: "medium",
        });

        const generatedImage =
            result.data?.[0];

        if (!generatedImage) {
          throw new Error(
              "No generated image returned.",
          );
        }

        let imageBuffer;

        // Most GPT image responses return base64 image data.
        if (generatedImage.b64_json) {
          imageBuffer = Buffer.from(
              generatedImage.b64_json,
              "base64",
          );
        } else if (generatedImage.url) {
          const imageResponse =
              await fetch(generatedImage.url);

          if (!imageResponse.ok) {
            throw new Error(
                `Failed to download generated image: ${
                  imageResponse.status
                }`,
            );
          }

          const arrayBuffer =
              await imageResponse.arrayBuffer();

          imageBuffer =
              Buffer.from(arrayBuffer);
        } else {
          throw new Error(
              "Generated image did not contain image data.",
          );
        }

        // ======================================================
        // SAVE TO FIREBASE STORAGE
        // ======================================================

        const bucket =
            admin.storage().bucket();

        const timestamp =
            Date.now();

        const filePath =
            `stamp_images/${attractionId}/` +
            `ai_stamp_${timestamp}.png`;

        const file =
            bucket.file(filePath);

        const downloadToken =
            crypto.randomUUID();

        await file.save(
            imageBuffer,
            {
              resumable: false,

              metadata: {
                contentType: "image/png",

                metadata: {
                  firebaseStorageDownloadTokens:
                      downloadToken,

                  type:
                      "heritage_stamp",

                  attractionId:
                      attractionId,

                  attractionName:
                      attractionName,

                  generatedBy:
                      "openai",
                },
              },
            },
        );

        // ======================================================
        // DOWNLOAD URL
        // ======================================================

        const encodedPath =
            encodeURIComponent(filePath);

        const imageUrl =
            "https://firebasestorage.googleapis.com/v0/b/" +
            `${bucket.name}/o/${encodedPath}` +
            `?alt=media&token=${downloadToken}`;

        return {
          success: true,
          imageUrl: imageUrl,
        };
      } catch (error) {
        console.error(
            "Stamp generation failed",
            error,
        );

        throw new HttpsError(
            "internal",
            error?.message ||
                "Unable to generate stamp image.",
        );
      }
    },
);

// ============================================================
// GENERATE BADGE IMAGE
// ============================================================

exports.generateBadgeImage = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 120,
      memory: "1GiB",
      enforceAppCheck: false,
      secrets: [OPENAI_API_KEY],
    },
    async (request) => {
      // ========================================================
      // AUTH
      // ========================================================

      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Please sign in before generating a badge.",
        );
      }

      const uid = request.auth.uid;

      // ========================================================
      // ADMIN CHECK
      // ========================================================

      const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw new HttpsError(
            "permission-denied",
            "User record not found.",
        );
      }

      const role = String(
          userDoc.data()?.role || "",
      ).trim().toLowerCase();

      if (role !== "admin") {
        throw new HttpsError(
            "permission-denied",
            "Only administrators can generate badge images.",
        );
      }

      // ========================================================
      // INPUT
      // ========================================================

      const challengeId = String(
          request.data?.challengeId || "",
      ).trim();

      const challengeTitle = String(
          request.data?.challengeTitle || "",
      ).trim();

      const badgeName = String(
          request.data?.badgeName || "",
      ).trim();

      const badgeDescription = String(
          request.data?.badgeDescription || "",
      ).trim();

      if (!challengeId ||
          !challengeTitle ||
          !badgeName) {
        throw new HttpsError(
            "invalid-argument",
            "challengeId, challengeTitle and badgeName are required.",
        );
      }

      // ========================================================
      // BADGE STYLE PROMPT
      // ========================================================

      const prompt = `
Create ONE square achievement badge illustration for a tourism
gamification mobile application.

CHALLENGE:
${challengeTitle}

BADGE NAME:
${badgeName}

BADGE DESCRIPTION:
${badgeDescription || "A reward badge for completing a tourism challenge."}

IMPORTANT STYLE:

Create a polished collectible achievement badge that belongs to
one consistent badge collection.

The badge should have:

- circular medal or emblem shape
- clean flat vector illustration
- clear outer ring border
- central symbolic icon representing the challenge
- symmetrical balanced composition
- warm modern tourism aesthetic
- subtle depth only, not 3D
- minimal clean shading
- strong readable silhouette
- professional mobile game achievement badge style

COLOR STYLE:

Use a coordinated tourism and eco-travel palette.

Suitable colours:
- dark green
- forest green
- olive green
- warm gold
- muted yellow
- cream
- beige
- terracotta
- soft blue
- white

Use no more than 4 main colours.

CENTRAL ICON:

Choose ONE simple symbolic icon that represents the challenge.

Examples:
- walking trail
- landmark
- passport
- map pin
- leaf
- bicycle
- footprints
- camera
- heritage building
- compass
- star

The icon should be clearly recognizable at small size.

TEXT:

Write only the badge name:

"${badgeName}"

Place the badge name neatly inside or underneath the emblem.

Use bold clean sans-serif text.

If the badge name is long, arrange it cleanly on two lines.

DO NOT INCLUDE:

- random text
- AI branding
- watermark
- signature
- logos
- dates
- QR codes
- realistic photography
- people
- 3D rendering
- glossy metallic 3D effects
- watercolor
- sketch style
- overly complex background

BACKGROUND:

Use a clean light or transparent-looking background.

The badge itself must remain clearly separated from the background.

FINAL RESULT:

A clean square achievement badge image suitable for displaying
inside a Flutter mobile application's My Badges page.

It should look like part of one consistent challenge badge collection.
`.trim();

      try {
        const openai = new OpenAI({
          apiKey: OPENAI_API_KEY.value(),
        });

        const result = await openai.images.generate({
          model: "gpt-image-2",
          prompt: prompt,
          size: "1024x1024",
          quality: "medium",
        });

        const generatedImage =
            result.data?.[0];

        if (!generatedImage) {
          throw new Error(
              "No generated badge image returned.",
          );
        }

        let imageBuffer;

        if (generatedImage.b64_json) {
          imageBuffer = Buffer.from(
              generatedImage.b64_json,
              "base64",
          );
        } else if (generatedImage.url) {
          const imageResponse =
              await fetch(generatedImage.url);

          if (!imageResponse.ok) {
            throw new Error(
                `Unable to download generated image: ${
                  imageResponse.status
                }`,
            );
          }

          const arrayBuffer =
              await imageResponse.arrayBuffer();

          imageBuffer =
              Buffer.from(arrayBuffer);
        } else {
          throw new Error(
              "Generated badge image contains no image data.",
          );
        }

        // ======================================================
        // FIREBASE STORAGE
        // ======================================================

        const bucket =
            admin.storage().bucket();

        const timestamp =
            Date.now();

        const filePath =
            `challenge_badges/${challengeId}/` +
            `ai_badge_${timestamp}.png`;

        const file =
            bucket.file(filePath);

        const downloadToken =
            crypto.randomUUID();

        await file.save(
            imageBuffer,
            {
              resumable: false,

              metadata: {
                contentType: "image/png",

                metadata: {
                  firebaseStorageDownloadTokens:
                      downloadToken,

                  type:
                      "challenge_badge",

                  challengeId:
                      challengeId,

                  challengeTitle:
                      challengeTitle,

                  badgeName:
                      badgeName,

                  generatedBy:
                      "openai",
                },
              },
            },
        );

        // ======================================================
        // DOWNLOAD URL
        // ======================================================

        const encodedPath =
            encodeURIComponent(filePath);

        const imageUrl =
            "https://firebasestorage.googleapis.com/v0/b/" +
            `${bucket.name}/o/${encodedPath}` +
            `?alt=media&token=${downloadToken}`;

        return {
          success: true,
          imageUrl: imageUrl,
        };
      } catch (error) {
        console.error(
            "Badge generation failed",
            error,
        );

        throw new HttpsError(
            "internal",
            error?.message ||
                "Unable to generate badge image.",
        );
      }
    },
);