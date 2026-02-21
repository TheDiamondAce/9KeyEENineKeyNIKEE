import os
from typing import Dict, Optional

from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import PlainTextResponse
from twilio.rest import Client
from twilio.twiml.voice_response import VoiceResponse, Gather
from dotenv import load_dotenv
load_dotenv()

MISSION_MP3 = "https://drive.google.com/uc?export=download&id=1cZdcQKPDC-zAUN82W558ovNzV-IebJr7"
ACCEPTED_MP3 = "https://drive.google.com/uc?export=download&id=12fdQIfzrN7B78xYSFCDxL-PcL5ObNqwE"
INVAILD_MP3 = "https://drive.google.com/uc?export=download&id=10ZfcgwDQyEHJGH2qI9CfIdkpQbK0vhwc"
DECLINED_MP3 = "https://drive.google.com/uc?export=download&id=1WAylzyW_eIt31Hf9AnguenFCew5sagNp"

app = FastAPI()

# Hackathon-friendly in-memory state store
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
    Godot calls this endpoint.
    Body JSON:
      {
        "phone": "+1XXXXXXXXXX",
        "consent": true,
        "base_url": "https://YOUR_NGROK_DOMAIN"
      }
    """
    phone = payload.get("phone")
    consent = payload.get("consent")
    base_url = payload.get("base_url")

    if consent is not True:
        raise HTTPException(status_code=400, detail="Consent required")
    if not phone or not isinstance(phone, str):
        raise HTTPException(status_code=400, detail="phone required (E.164 format like +14155552671)")
    if not base_url or not isinstance(base_url, str) or not base_url.startswith("https://"):
        raise HTTPException(status_code=400, detail="base_url required and must start with https://")

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
    """
    Godot polls this endpoint.
    """
    state = CALL_STATE.get(call_sid)
    if not state:
        return {"found": False, "call_sid": call_sid}
    return {"found": True, "call_sid": call_sid, "status": state["status"], "choice": state["choice"]}


@app.post("/twilio/voice")
async def twilio_voice():
    """
    Twilio Voice webhook: returns TwiML instructions for the call.
    """
    vr = VoiceResponse()

    #vr.say("Mission control here.", voice="alice")
    #vr.play(MISSION_MP3)
    #vr.say("Press 1 to accept the mission. Press 2 to decline.", voice="alice")

    gather = Gather(
        num_digits=1,
        action="/twilio/choice",
        method="POST",
        timeout=15,
    )
    gather.play(MISSION_MP3)
    vr.append(gather)

    vr.say("No input received. Goodbye.", voice="alice")
    vr.hangup()

    return PlainTextResponse(str(vr), media_type="application/xml")


@app.post("/twilio/choice")
async def twilio_choice(
    CallSid: str = Form(...),
    Digits: str = Form(None),
):
    """
    Twilio posts the digit choice here.
    """
    if CallSid not in CALL_STATE:
        CALL_STATE[CallSid] = {"status": "answered", "choice": None}

    if Digits == "1":
        CALL_STATE[CallSid]["choice"] = "accepted"
        msg = ACCEPTED_MP3
        #msg = "Mission accepted. Your brother Antonio will be waiting"
    elif Digits == "2":
        CALL_STATE[CallSid]["choice"] = "declined"
        msg = DECLINED_MP3 
        #msg = "Mission declined. Returning control to the game. Rest. In. Peace."
    else:
        CALL_STATE[CallSid]["choice"] = "invalid"
        msg = INVAILD_MP3

    vr = VoiceResponse()
    vr.play(msg)
    #vr.say(msg, voice="alice")
    vr.hangup()

    return PlainTextResponse(str(vr), media_type="application/xml")


@app.post("/twilio/status")
async def twilio_status(request: Request):
    """
    Twilio status callback: initiated/ringing/answered/completed
    """
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
