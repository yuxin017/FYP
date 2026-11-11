"""Revise the architecture and email-only authentication scope of the proposal."""
from io import BytesIO
from pathlib import Path
import hashlib
import json

from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph
import pypdfium2 as pdfium
from pypdfium2 import raw as pdfium_raw
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path.home() / "Downloads" / "FYP Title.pdf"
TARGET = ROOT / "output" / "pdf" / "FYP Proposal - Updated.pdf"
PREVIEWS = ROOT / "tmp" / "pdfs"

pdfmetrics.registerFont(TTFont("ProposalArial", r"C:\Windows\Fonts\arial.ttf"))
pdfmetrics.registerFont(TTFont("ProposalArialBold", r"C:\Windows\Fonts\arialbd.ttf"))

sections = [
    ("Frontend", [
        "- Flutter (Dart) - cross platform mobile application (iOS / Android) for visitor",
        "- Web Interface - Admin management dashboard",
        "- Kiosk Interface - Photo printing kiosk",
    ]),
    ("Backend", [
        "- Firebase Authentication - Secure user login and account management",
        "- Cloud Firestore (Database) - Stores visitor profiles, tickets, attractions, reservations, and photo records",
        "- Node.js - Server-side APIs for queue reservation, voucher distribution, notification processing, system integration, and data processing",
        "- Python - AI inference, computer vision, and email delivery invoked by the Node.js application services",
    ]),
    ("Application Deployment", [
        "- Firebase Spark - Uses the existing Firebase project for authentication and shared application data",
        "- Application Services - Node.js and Python run on the presentation computer and connect to Firebase over the internet. Background processing runs while these services are running.",
    ]),
    ("Core Technology", [
        "- WiFi-based Indoor Positioning (IndoorAtlas) - Combines WiFi signal strength (RSSI), geomagnetic data, and device sensors for indoor navigation within the theme park",
        "- Landmark Image Recognition (Computer Vision) - Detects nearby landmarks using the camera when WiFi signal is weak",
        "- Crowd Heatmap Analysis (Mapbox + KDE Algorithm) - Monitors visitor distribution and identifies overcrowded areas",
        "- AI Recommendation System (Python) - Generates personalized attraction and itinerary recommendations",
        "- Image Recognition (OpenCV) - Matches visitor faces with attraction photos for automatic photo identification",
        "- QR Code and NFC Technology - Digital ticket validation, attraction entry, and photo printing services",
    ]),
]


def email_authentication_page():
    """Remove the old two-line login bullet while preserving the rest of page 2."""
    document = pdfium.PdfDocument(str(SOURCE))
    page = document[1]
    removed = 0
    for obj in list(page.get_objects(filter=[pdfium_raw.FPDF_PAGEOBJ_TEXT])):
        left, bottom, right, top = obj.get_bounds()
        if left >= 71 and right <= 530 and bottom >= 211 and top <= 240:
            assert obj.level == 0, "Recheck the source authentication text layout."
            page.remove_obj(obj)
            obj.close()
            removed += 1
    assert 80 <= removed <= 150, "Recheck the source authentication text block."
    page.gen_content()
    sanitized = BytesIO()
    document.save(sanitized)
    document.close()
    sanitized.seek(0)
    updated = PdfReader(sanitized).pages[1]
    overlay = BytesIO()
    replacement = canvas.Canvas(overlay, pagesize=(612, 792))
    replacement.setFont("ProposalArial", 11)
    replacement.drawString(72, 229.66, "- Register and log in using email and password")
    replacement.drawString(72, 215.11, "- Unlock a retained session with Face ID / fingerprint on supported devices")
    replacement.showPage()
    replacement.save()
    updated.merge_page(PdfReader(overlay).pages[0])
    return updated


def main():
    original_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    original = PdfReader(SOURCE)
    assert len(original.pages) == 5, "Recheck the source proposal before editing."
    assert "Firebase Cloud Functions" in " ".join(original.pages[0].extract_text().split())
    style = ParagraphStyle("Body", fontName="ProposalArial", fontSize=11, leading=14.55)
    heading_style = ParagraphStyle("Heading", parent=style, fontName="ProposalArialBold")
    buffer = BytesIO()
    page = canvas.Canvas(buffer, pagesize=(612, 792))
    y = 720.0
    for heading, paragraphs in sections:
        for text, current_style in [(heading, heading_style), *[(p, style) for p in paragraphs]]:
            paragraph = Paragraph(text, current_style)
            _, height = paragraph.wrap(468, 700)
            paragraph.drawOn(page, 72, y - height)
            y -= height
            if text == heading:
                y -= 14.55
        y -= 14.55
    assert y >= 72, "The updated page exceeds its bottom margin."
    page.showPage()
    page.save()
    writer = PdfWriter()
    writer.add_page(PdfReader(buffer).pages[0])
    writer.add_page(email_authentication_page())
    for old_page in original.pages[2:]:
        writer.add_page(old_page)
    writer.add_metadata({
        "/Title": "Smart Theme Park Management System - Project Proposal",
        "/Subject": "Firebase Spark architecture, email-only sign-in and selected indoor positioning provider",
    })
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    with TARGET.open("wb") as output:
        writer.write(output)
    revised = PdfReader(TARGET)
    assert len(revised.pages) == 5
    text = "\n".join(p.extract_text() for p in revised.pages)
    assert "Firebase Cloud Functions" not in text
    assert "IndoorAtlas" in text and "Firebase Spark" in text
    assert "presentation computer" in text and "Node.js" in text
    assert "mobile number" not in " ".join(text.split()).lower()
    assert "email and password" in text and "retained session" in text
    for old, new in zip(original.pages[2:], revised.pages[2:]):
        assert old.extract_text() == new.extract_text()
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == original_hash
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    old_render, new_render = pdfium.PdfDocument(str(SOURCE)), pdfium.PdfDocument(str(TARGET))
    for index in range(2, 5):
        before = old_render[index].render(scale=1).to_pil().convert("RGB")
        after = new_render[index].render(scale=1).to_pil().convert("RGB")
        assert before.size == after.size and before.tobytes() == after.tobytes(), f"Page {index + 1} changed."
    before = old_render[1].render(scale=1).to_pil().convert("RGB")
    after = new_render[1].render(scale=1).to_pil().convert("RGB")
    # Only the authentication bullet is revised; keep every other pixel on page 2.
    unchanged_before, unchanged_after = before.copy(), after.copy()
    for image in (unchanged_before, unchanged_after):
        ImageDraw.Draw(image).rectangle((70, 550, 532, 583), fill="white")
    assert unchanged_before.tobytes() == unchanged_after.tobytes(), "Page 2 changed outside the authentication block."
    new_render[0].render(scale=1.7).to_pil().save(PREVIEWS / "proposal-updated-page1.png")
    new_render[1].render(scale=1.7).to_pil().save(PREVIEWS / "proposal-updated-page2.png")
    sheet = Image.new("RGB", (1200, 550), "#dddddd")
    draw = ImageDraw.Draw(sheet)
    for index in range(5):
        thumb = new_render[index].render(scale=.37).to_pil().convert("RGB")
        sheet.paste(thumb, (index * 240 + 7, 30))
        draw.text((index * 240 + 9, 10), f"Page {index + 1}", fill="black")
    sheet.save(PREVIEWS / "proposal-updated-overview.png")
    result = {"pages": 5, "preservedPages": [3, 4, 5], "authenticationBlockOnlyOnPage2": True, "phoneLoginRemoved": True, "sourceUnchanged": True, "bottomMarginPoints": round(y, 2), "output": str(TARGET)}
    (PREVIEWS / "proposal-verification.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
