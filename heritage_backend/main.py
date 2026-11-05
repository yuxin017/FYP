from __future__ import annotations

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from google.cloud import vision

app = FastAPI(title="EcoTravel Heritage Recognition API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "EcoTravel heritage recognition backend is running"}


@app.post("/recognize")
async def recognize(file: UploadFile = File(...)) -> dict:
    if file.content_type and not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Please upload an image file")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Uploaded image is empty")

    try:
        client = vision.ImageAnnotatorClient()
        image = vision.Image(content=content)

        landmark_response = client.landmark_detection(image=image)
        if landmark_response.error.message:
            raise RuntimeError(landmark_response.error.message)

        candidates: list[str] = []
        landmarks: list[dict] = []

        for annotation in landmark_response.landmark_annotations:
            name = annotation.description.strip()
            if name:
                candidates.append(name)
            landmarks.append(
                {
                    "name": annotation.description,
                    "confidence": float(annotation.score),
                }
            )

        # Fallback for photos where Landmark Detection has no result.
        if not candidates:
            web_response = client.web_detection(image=image)
            if web_response.error.message:
                raise RuntimeError(web_response.error.message)
            web = web_response.web_detection
            if web:
                for label in web.best_guess_labels:
                    if label.label:
                        candidates.append(label.label)
                for entity in web.web_entities[:8]:
                    if entity.description:
                        candidates.append(entity.description)

        # Preserve order while removing duplicates.
        unique_candidates = list(dict.fromkeys(candidates))
        return {
            "candidate_names": unique_candidates[:12],
            "google_landmarks": landmarks,
        }
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Google Cloud Vision error: {exc}",
        ) from exc
