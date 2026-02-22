import os
from typing import Dict, Optional

from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import PlainTextResponse
from fastapi.staticfiles import StaticFiles
from twilio.rest import Client
from twilio.twiml.voice_response import VoiceResponse, Gather
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

# Serve local audio files from: call/audio/*.mp3
# Folder structure:
# call/
#   main.py
#   audio/
#     mission.mp3
#     accepted.mp3
#     declined.mp3
#     invalid.mp3
app.mount("/audio", StaticFiles(directory="audio"), name="audio")

# call_sid -> {"status": str, "choice": Optional[str]}
CALL_STATE: Dict[str, Dict[str, Optional[str]]] = {}


def get_env(name: str) -> str:
    v = os.getenv(name)
    if not v:
        raise RuntimeError(f"Missing environment variable: {name}")
    return v


def twilio_client() -> Client:
    return Client(get_env("TWILIO_ACCOUNT_SID"), get_env("TWILIO_AUTH_TOKEN"))


@app.get("/")
def health():
    return {"ok": True, "service": "mission-call"}


@app.post("/start_call")
async def start_call(payload: dict):
    """
    Body JSON:
      {
        "phone": "+1XXXXXXXXXX",
        "consent": true,
        "base_url": "https://YOUR_PUBLIC_TUNNEL_DOMAIN"
      }
    """
    phone = payload.get("phone")
    consent = payload.get("consent")
    base_url = payload.get("base_url")

    if consent is not True:
        raise HTTPException(status_code=400, detail="Consent required")
    if not phone or not isinstance(phone, str) or not phone.startswith("+"):
        raise HTTPException(status_code=400, detail="phone required in E.164 format like +14155552671")
    if not base_url or not isinstance(base_url, str) or not base_url.startswith("https://"):
        raise HTTPException(status_code=400, detail="base_url required and must start with https://")

    # Prevent //twilio/voice bugs
    base_url = base_url.rstrip("/")

    from_number = get_env("TWILIO_FROM_NUMBER")
    client = twilio_client()

    call = client.calls.create(
        to=phone,
        from_=from_number,
        url=f"{base_url}/twilio/voice",
        method="POST",
        status_callback=f"{base_url}/twilio/status",
        status_callback_method="POST",
        status_callback_event=["initiated", "ringing", "answered", "completed"],
    )

    CALL_STATE[call.sid] = {"status": "initiated", "choice": None}
    return {"ok": True, "call_sid": call.sid}


@app.get("/mission_state")
def mission_state(call_sid: str):
    state = CALL_STATE.get(call_sid)
    if not state:
        return {"found": False, "call_sid": call_sid}
    return {"found": True, "call_sid": call_sid, "status": state["status"], "choice": state["choice"]}


@app.post("/twilio/voice")
async def twilio_voice(request: Request):
    """
    Plays mission.mp3 *inside* Gather so the caller can press 1/2 at any time.
    """
    host = str(request.base_url).rstrip("/")  # e.g. https://xxxx.ngrok-free.app

    vr = VoiceResponse()

    gather = Gather(
        num_digits=1,
        action="/twilio/choice",
        method="POST",
        timeout=30,
        # Lets user interrupt the audio with a keypress (barge-in)
        barge_in=True,
    )
    gather.play(f"{host}/audio/mission.mp3")
    vr.append(gather)

    # If they never press anything:
    vr.play(f"{host}/audio/invalid.mp3")
    vr.hangup()

    return PlainTextResponse(str(vr), media_type="application/xml")


@app.post("/twilio/choice")
async def twilio_choice(
    request: Request,
    CallSid: str = Form(...),
    Digits: str = Form(None),
):
    """
    If caller presses 1/2 (even mid-mission audio), Twilio posts here immediately.
    We then play accepted/declined/invalid and hang up.
    """
    host = str(request.base_url).rstrip("/")

    if CallSid not in CALL_STATE:
        CALL_STATE[CallSid] = {"status": "answered", "choice": None}

    vr = VoiceResponse()

    if Digits == "1":
        CALL_STATE[CallSid]["choice"] = "accepted"
        vr.play(f"{host}/audio/accepted.mp3")
    elif Digits == "2":
        CALL_STATE[CallSid]["choice"] = "declined"
        vr.play(f"{host}/audio/declined.mp3")
    else:
        CALL_STATE[CallSid]["choice"] = "invalid"
        vr.play(f"{host}/audio/invalid.mp3")

    vr.hangup()
    return PlainTextResponse(str(vr), media_type="application/xml")


@app.post("/twilio/status")
async def twilio_status(request: Request):
    form = await request.form()
    call_sid = form.get("CallSid")
    status = form.get("CallStatus")

    if call_sid:
        if call_sid not in CALL_STATE:
            CALL_STATE[call_sid] = {"status": status or "unknown", "choice": None}
        else:
            if status:
                CALL_STATE[call_sid]["status"] = status

    return {"ok": True}