# EcoTravel Cultural & Heritage Recognition Backend

This backend keeps the Google Cloud service-account credential out of the Flutter app.

## 1. Create a virtual environment

```powershell
cd heritage_backend
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## 2. Configure Google Cloud Vision

1. Create or select a Google Cloud project.
2. Enable **Cloud Vision API**.
3. Create a service account allowed to call Cloud Vision.
4. Download the service-account JSON to a safe local folder.
5. Set the credential environment variable:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\your-service-account.json"
```

Do not put the JSON credential inside Flutter or commit it to Git.

## 3. Start the server

```powershell
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Open:

```text
http://127.0.0.1:8000/docs
```

The Flutter service uses `http://10.0.2.2:8000` for the Android emulator.
For a physical Android phone, change `HeritageRecognitionService.baseUrl` to your computer's LAN IPv4 address.
