"""Local CPU inference. JSON-lines protocol; photographs and vectors never go to logs."""
from __future__ import annotations

import base64
import hashlib
import json
import math
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / ".local" / "python-deps"))
os.environ.setdefault("OPENCV_IO_MAX_IMAGE_PIXELS", "20000000")
import cv2
import numpy as np

cv2.setNumThreads(2)
_detector = None
_recognizer = None


def models():
    global _detector, _recognizer
    if _detector is None:
        manifest = json.loads((ROOT / "ai/model_manifest.json").read_text())
        paths = {}
        for name, item in manifest["models"].items():
            path = ROOT / ".local/models" / item["file"]
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
                raise ValueError("Photo recognition models are unavailable. Run the AI setup command.")
            paths[name] = str(path)
        _detector = cv2.FaceDetectorYN.create(paths["yunet"], "", (320, 320), 0.90, 0.3, 5000)
        _recognizer = cv2.FaceRecognizerSF.create(paths["sface"], "")
    return _detector, _recognizer


def image(value):
    if not isinstance(value, str) or len(value) > 12_000_000:
        raise ValueError("Choose a photo smaller than 8 MB.")
    try:
        binary = base64.b64decode(value, validate=True)
        result = cv2.imdecode(np.frombuffer(binary, np.uint8), cv2.IMREAD_COLOR)
    except Exception as error:
        raise ValueError("Choose a readable JPEG or PNG photo.") from error
    if result is None or min(result.shape[:2]) < 80 or result.shape[0] * result.shape[1] > 20_000_000:
        raise ValueError("Choose a clear photo between 80 pixels and 20 megapixels.")
    return result


def resize(value, limit):
    h, w = value.shape[:2]
    if max(h, w) <= limit:
        return value
    scale = limit / max(h, w)
    return cv2.resize(value, (round(w * scale), round(h * scale)), interpolation=cv2.INTER_AREA)


def jpeg(value, byte_limit=650_000):
    for quality in [90, 82, 74, 65, 55, 45]:
        ok, encoded = cv2.imencode(".jpg", value, [cv2.IMWRITE_JPEG_QUALITY, quality])
        if ok and len(encoded) <= byte_limit:
            return base64.b64encode(encoded).decode("ascii")
    return jpeg(resize(value, max(100, int(max(value.shape[:2]) * 0.75))), byte_limit)


def faces(value):
    detector, recognizer = models()
    source = resize(value, 1280)
    h, w = source.shape[:2]
    detector.setInputSize((w, h))
    _, detected = detector.detect(source)
    result = []
    for face in [] if detected is None else detected[:40]:
        aligned = recognizer.alignCrop(source, face)
        vector = recognizer.feature(aligned).reshape(-1)
        vector /= max(float(np.linalg.norm(vector)), 1e-9)
        result.append({"box": [round(float(face[0]) / w, 6), round(float(face[1]) / h, 6), round(float(face[2]) / w, 6), round(float(face[3]) / h, 6)], "score": round(float(face[-1]), 5), "feature": vector.round(7).tolist(), "facePixels": float(min(face[2:4]))})
    return result


def preview(value):
    source = resize(value, 900)
    overlay = source.copy()
    h, w = source.shape[:2]
    scale = max(0.45, w / 1100)
    for y in range(45, h, max(90, h // 4)):
        for x in range(-90, w, 290):
            cv2.putText(overlay, "THEME PARK - PREVIEW", (x, y), cv2.FONT_HERSHEY_SIMPLEX, scale, (245, 245, 245), 2, cv2.LINE_AA)
    return cv2.addWeighted(overlay, 0.58, source, 0.42, 0)


def render(value, edits):
    if not isinstance(edits, dict) or set(edits) - {"filter", "rotation", "crop", "beauty", "brightness", "sticker", "intensity"}:
        raise ValueError("Review the selected photo edits.")
    result = value.copy()
    crop = edits.get("crop")
    if crop:
        x, y, w, h = [float(crop.get(k, 0)) for k in ["x", "y", "width", "height"]]
        if not all(math.isfinite(v) for v in [x, y, w, h]) or min(x, y) < 0 or min(w, h) < 0.1 or x + w > 1.001 or y + h > 1.001:
            raise ValueError("Choose a crop inside the photo.")
        height, width = result.shape[:2]
        result = result[round(y * height):round((y + h) * height), round(x * width):round((x + w) * width)].copy()
    rotation = edits.get("rotation", 0)
    if rotation not in [0, 90, 180, 270]:
        raise ValueError("Choose a valid photo rotation.")
    if rotation:
        result = np.rot90(result, -rotation // 90).copy()
    beauty = float(edits.get("beauty", 0))
    brightness = float(edits.get("brightness", 0))
    if not math.isfinite(beauty + brightness) or not 0 <= beauty <= 0.5 or not -0.3 <= brightness <= 0.3:
        raise ValueError("Review the photo enhancement settings.")
    if beauty:
        smooth = cv2.bilateralFilter(result, 7, 35, 35)
        result = cv2.addWeighted(result, 1 - beauty, smooth, beauty, 0)
    work = result.astype(np.float32)
    original_colors = work.copy()
    intensity = float(edits.get("intensity", 1))
    if not math.isfinite(intensity) or not 0 <= intensity <= 1:
        raise ValueError("Review the filter intensity.")
    kind = edits.get("filter", "original")
    if kind == "warm":
        work *= np.array([0.91, 1.02, 1.12], np.float32)
    elif kind == "cool":
        work *= np.array([1.14, 1.02, 0.94], np.float32)
    elif kind == "vintage":
        work = cv2.transform(work, np.array([[0.131, 0.534, 0.272], [0.168, 0.686, 0.349], [0.189, 0.769, 0.393]], np.float32)) * 0.9 + 12
    elif kind == "mono":
        work = cv2.cvtColor(cv2.cvtColor(result, cv2.COLOR_BGR2GRAY), cv2.COLOR_GRAY2BGR).astype(np.float32)
    elif kind == "vivid":
        gray = cv2.cvtColor(result, cv2.COLOR_BGR2GRAY).astype(np.float32)[:, :, None]
        work = gray + (work - gray) * 1.25
    elif kind != "original":
        raise ValueError("Choose a supported photo filter.")
    result = np.clip(work * intensity + original_colors * (1-intensity) + brightness * 255, 0, 255).astype(np.uint8)
    sticker = edits.get("sticker")
    if sticker:
        kind = sticker.get("type")
        x, y, scale = float(sticker.get("x", .8)), float(sticker.get("y", .8)), float(sticker.get("scale", .12))
        if kind not in ["heart", "star", "smile"] or not all(math.isfinite(v) for v in [x, y, scale]) or not 0 <= min(x, y) <= max(x, y) <= 1 or not .04 <= scale <= .3:
            raise ValueError("Review the sticker position and size.")
        h, w = result.shape[:2]
        center = (round(x * w), round(y * h))
        radius = max(8, round(min(w, h) * scale))
        if kind == "star":
            polygon = np.array([(round(center[0] + radius * (1 if i % 2 == 0 else .45) * math.cos(i * math.pi / 5 - math.pi / 2)), round(center[1] + radius * (1 if i % 2 == 0 else .45) * math.sin(i * math.pi / 5 - math.pi / 2))) for i in range(10)], np.int32)
            cv2.fillPoly(result, [polygon], (80, 205, 255), lineType=cv2.LINE_AA)
        elif kind == "heart":
            t = np.linspace(0, 2 * math.pi, 80)
            polygon = np.stack((center[0] + radius * np.sin(t) ** 3, center[1] - radius * (13 * np.cos(t) - 5 * np.cos(2 * t) - 2 * np.cos(3 * t) - np.cos(4 * t)) / 17), axis=1).astype(np.int32)
            cv2.fillPoly(result, [polygon], (100, 95, 205), lineType=cv2.LINE_AA)
        else:
            cv2.circle(result, center, radius, (80, 220, 255), -1, cv2.LINE_AA)
            for sign in [-1, 1]:
                cv2.circle(result, (center[0] + sign * radius // 3, center[1] - radius // 4), max(2, radius // 12), (40, 40, 40), -1, cv2.LINE_AA)
            cv2.ellipse(result, center, (radius // 2, radius // 2), 0, 15, 165, (40, 40, 40), max(2, radius // 15), cv2.LINE_AA)
    return result


def handle(data):
    op = data.get("operation")
    if op == 'check_email':
        from mail_delivery import check_smtp
        return check_smtp(data)
    if op == 'send_photo_email':
        from mail_delivery import send_photo_email
        return send_photo_email(data)
    if op == 'send_reset_email':
        from mail_delivery import send_reset_email
        return send_reset_email(data)
    if op in ['recommendations', 'queue_density', 'assistant', 'landmark_features', 'recognize_landmark','anomalies']:
        import park_intelligence as intelligence
        return intelligence.landmark_features(data['imageBase64']) if op == 'landmark_features' else getattr(intelligence, op)(data)
    if op == "health":
        models()
        return {"ready": True, "opencv": cv2.__version__, "models": ["YuNet", "SFace"]}
    if op == "enroll":
        detected = faces(image(data.get("imageBase64")))
        if len(detected) != 1 or detected[0]["facePixels"] < 75:
            raise ValueError("Choose a clear, front-facing selfie with one face and good lighting.")
        return {"feature": detected[0]["feature"], "score": detected[0]["score"]}
    if op == "prepare_photo":
        original = resize(image(data.get("imageBase64")), 1920)
        return {"originalBase64": jpeg(original), "previewBase64": jpeg(preview(original), 150_000), "width": original.shape[1], "height": original.shape[0], "faces": faces(original)}
    if op == "render_photo":
        output = render(image(data.get("imageBase64")), data.get("edits", {}))
        return {"imageBase64": jpeg(output, 900_000), "width": output.shape[1], "height": output.shape[0]}
    if op == "match_faces":
        templates = data.get("templates", [])
        if len(templates) > 2000 or len(data.get("faces", [])) > 40:
            raise ValueError("Photo matching batch is too large.")
        matches = []
        for face in data.get("faces", []):
            feature = np.asarray(face["feature"], np.float32)
            if feature.shape != (128,) and feature.shape != (512,):
                raise ValueError("Face template is not compatible with this recognition model.")
            scores = []
            for template in templates:
                target = np.asarray(template["feature"], np.float32)
                if target.shape != feature.shape or not np.all(np.isfinite(target)):
                    continue
                score = float(np.dot(feature, target) / max(np.linalg.norm(feature) * np.linalg.norm(target), 1e-9))
                scores.append((score, template["uid"]))
            scores.sort(reverse=True)
            if scores and scores[0][0] >= .45 and (len(scores) < 2 or scores[0][0] - scores[1][0] >= .06):
                matches.append({"uid": scores[0][1], "score": round(scores[0][0], 5), "box": face.get("box")})
        return {"matches": matches}
    raise ValueError("This recognition operation is unavailable.")


if __name__ == "__main__":
    for line in sys.stdin:
        request = {}
        try:
            if len(line) > 16_000_000:
                raise ValueError("Photo request is too large.")
            request = json.loads(line)
            result = {"id": request.get("id"), "result": handle(request)}
        except ValueError as error:
            result = {"id": request.get("id"), "error": str(error)}
        except Exception:
            result = {"id": request.get("id"), "error": "Photo recognition could not finish. Check the AI service and try again."}
        print(json.dumps(result, separators=(",", ":"), allow_nan=False), flush=True)
