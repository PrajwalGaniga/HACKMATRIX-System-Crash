import asyncio
import os
import json
import datetime
import socketio
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from motor.motor_asyncio import AsyncIOMotorClient
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────────────────
# Configuration  (reads from .env, with hardcoded fallbacks)
# ─────────────────────────────────────────────────────────
GEMINI_API_KEY   = os.getenv("GEMINI_API_KEY",   "AIzaSyB02OqNj_f2dFGnLxXPrmXKNvo007J2GcM")
TWILIO_SID       = os.getenv("TWILIO_SID",       "")
TWILIO_AUTH      = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_NUMBER    = os.getenv("TWILIO_NUMBER",     "+18568806679")
CALL_TARGET      = os.getenv("CALL_TARGET",       "+919110687983")
MONGODB_URL      = os.getenv("MONGO_URI",         "mongodb://localhost:27017")

genai.configure(api_key=GEMINI_API_KEY)
gemini_model = genai.GenerativeModel("gemini-2.5-flash")

# ─────────────────────────────────────────────────────────
# Socket.IO + FastAPI setup
# ─────────────────────────────────────────────────────────
sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*",
    logger=False,
    engineio_logger=False,
)

app = FastAPI(title="Aegis.ai Backend v2")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

combined_app = socketio.ASGIApp(sio, other_asgi_app=app)

# ─────────────────────────────────────────────────────────
# MongoDB
# ─────────────────────────────────────────────────────────
mongo_client = None
db = None

@app.on_event("startup")
async def startup_event():
    global mongo_client, db
    try:
        mongo_client = AsyncIOMotorClient(MONGODB_URL, serverSelectionTimeoutMS=3000)
        db = mongo_client["aegis_db"]
        users_col = db["users"]
        existing = await users_col.find_one({"name": "Prajwal"})
        if not existing:
            await users_col.insert_one({
                "name": "Prajwal",
                "cgpa": 9.0,
                "interests": ["React", "ML", "E-Sports", "AI"],
                "role": "Professional Gamer / ML Engineer",
                "recovery_score": 87,
                "blink_normalization": 76,
                "sessions_today": 4,
                "tilt_events_avoided": 12,
            })
        print("✅ MongoDB connected and seeded.")
    except Exception as e:
        print(f"⚠️  MongoDB unavailable – mock data will be used. ({e})")
        db = None

@app.on_event("shutdown")
async def shutdown_event():
    if mongo_client:
        mongo_client.close()

# ─────────────────────────────────────────────────────────
# Active-window detection (pygetwindow)
# ─────────────────────────────────────────────────────────
def get_active_app() -> str:
    """
    Returns label of the currently focused window.
    Falls back gracefully if pygetwindow fails.
    """
    try:
        import pygetwindow as gw
        win = gw.getActiveWindow()
        if win is None:
            return "Unknown App"
        title = win.title or "Unknown App"
        lower = title.lower()
        if any(k in lower for k in ["pubg", "battlegrounds", "steam", "game"]):
            return f"PUBG / Game ({title})"
        if any(k in lower for k in ["visual studio code", "vscode", "code"]):
            return f"VS Code ({title})"
        if any(k in lower for k in ["chrome", "firefox", "edge", "browser"]):
            return f"Browser ({title})"
        return title[:60]
    except Exception as e:
        print(f"pygetwindow error: {e}")
        return "Aegis.ai Dashboard"

# ─────────────────────────────────────────────────────────
# MongoDB: log intervention event
# ─────────────────────────────────────────────────────────
async def log_intervention(au_data: dict, gemini_result: dict, active_app: str, called: bool):
    if db is None:
        return
    try:
        await db["interventions"].insert_one({
            "timestamp": datetime.datetime.utcnow(),
            "active_app": active_app,
            "au_data":    au_data,
            "stress_level": gemini_result.get("stress_level"),
            "action":       gemini_result.get("action"),
            "confidence":   gemini_result.get("confidence"),
            "reasoning":    gemini_result.get("reasoning"),
            "toast_msg":    gemini_result.get("toast_msg"),
            "twilio_called": called,
        })
        # Atomically increment tilt_events_avoided for user
        if gemini_result.get("action") == "INTERVENE":
            await db["users"].update_one(
                {"name": "Prajwal"},
                {"$inc": {"tilt_events_avoided": 1, "sessions_today": 0}}
            )
    except Exception as e:
        print(f"Mongo log error: {e}")

# ─────────────────────────────────────────────────────────
# Gemini — Context-Aware Reasoning (gemini-2.5-flash)
# ─────────────────────────────────────────────────────────
async def run_gemini_reasoning(au_data: dict, active_app: str) -> dict:
    prompt = f"""
You are the Cognitive Engine for Aegis.ai, an AI mental resilience system.

Context:
- User: Prajwal (CGPA 9.0, ML Engineer & Professional Gamer)
- Currently active application: {active_app}
- Real-time facial action unit data from YOLOv8:
  • AU4 (Brow Lowerer / Frustration): {au_data.get('au4', 0):.2f}  (0-1)
  • AU23 (Lip Tightener / Suppressed Anger): {au_data.get('au23', 0):.2f}  (0-1)
  • Blink Rate: {au_data.get('blink_rate', 15)} blinks/min  (healthy: >12)

Your task:
1. Classify stress: HIGH (au23>0.7 AND blink<10) | ELEVATED (au23>0.5 OR blink<12) | STABLE
2. Generate a witty, context-specific "hype-man" toast message — tone of a caring best friend.
   - PUBG/game context → gamer-themed, energetic
   - VS Code/coding → coding joke, encouraging
   - Under 120 characters
3. Pick the BEST game for this context:
   - High cognitive load/racing thoughts → "MINDFUL_PUZZLE" (color sorting for slow focus)
   - Angry/frustrated/tilt → "BUBBLE_WRAP" (rapid tactile popping to release energy)
   - Fast heart rate/panic → "BREATHING_TRAINER" (4-4-4 box breathing guide)
   - Overwhelmed/stuck → "RELAXING_COLORING" (art therapy, filling mandala)
   - General burnout/mild stress → "IDLE_GARDEN" (gentle plant growing tap mechanics)
4. Generate breathing_tip: a 4-7-8 or box breathing instruction, 1 sentence, warm tone.
5. Generate rest_reminder: friendly nudge to hydrate/stand/look away, 1 sentence.
6. TwiML for Polly.Joanna voice call — max 2 warm sentences. Trigger ONLY on HIGH.

Respond ONLY with valid JSON, no markdown fences:
{{
  "stress_level": "HIGH" | "ELEVATED" | "STABLE",
  "action": "INTERVENE" | "MONITOR" | "NONE",
  "level": "AMBER_SHIFT" | "ELEVATED_ALERT" | "NONE",
  "confidence": 0.0,
  "reasoning": "one sentence",
  "toast_msg": "context-aware hype message",
  "toast_emoji": "single emoji",
  "intervention_tip": "calming micro-tip",
  "breathing_tip": "breathe in for 4s, hold 4s, out 4s — you've got this",
  "rest_reminder": "Drink some water and look out a window for 20 seconds.",
  "game_id": "BUBBLE_WRAP" | "RELAXING_COLORING" | "BREATHING_TRAINER" | "MINDFUL_PUZZLE" | "IDLE_GARDEN",
  "twiml_script": "<Response><Say voice='Polly.Joanna'>YOUR_SCRIPT</Say></Response>",
  "trigger_call": true | false
}}
"""
    try:
        response = await asyncio.to_thread(gemini_model.generate_content, prompt)
        raw = response.text.strip()
        if "```" in raw:
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        return json.loads(raw.strip())
    except Exception as e:
        print(f"Gemini error: {e}")
        # Deterministic fallback
        au23 = au_data.get("au23", 0)
        blink = au_data.get("blink_rate", 15)
        if au23 > 0.7 and blink < 10:
            return {
                "stress_level": "HIGH", "action": "INTERVENE", "level": "AMBER_SHIFT",
                "confidence": 0.92, "reasoning": "High AU23 + critical blink rate.",
                "toast_msg": f"Bro, breathe. Even GPUs need cooling time. [{active_app}]",
                "toast_emoji": "🔥",
                "intervention_tip": "Slow breath in for 4s, hold 4s, out 4s.",
                "twiml_script": "<Response><Say voice='Polly.Joanna'>Hey Prajwal, Aegis detected you might be tilting. Take a slow breath — you've got this.</Say></Response>",
                "trigger_call": True,
            }
        return {
            "stress_level": "STABLE", "action": "NONE", "level": "NONE",
            "confidence": 0.5, "reasoning": "Markers nominal.",
            "toast_msg": "You are in the zone. Keep going!", "toast_emoji": "✨",
            "intervention_tip": "Stay focused.", "twiml_script": "", "trigger_call": False,
        }

# ─────────────────────────────────────────────────────────
# Twilio — voice call helper
# ─────────────────────────────────────────────────────────
async def make_twilio_call(twiml_script: str) -> dict:
    if not TWILIO_SID or not TWILIO_AUTH:
        print("⚠️  Twilio creds missing — skipping call (add TWILIO_SID/TWILIO_AUTH_TOKEN to .env)")
        return {"status": "skipped", "reason": "no_credentials"}
    try:
        from twilio.rest import Client as TwilioClient
        from twilio.twiml.voice_response import VoiceResponse

        # Build TwiML if Gemini passed raw XML, otherwise wrap it
        if twiml_script and twiml_script.startswith("<Response>"):
            twiml = twiml_script
        else:
            vr = VoiceResponse()
            vr.say(
                twiml_script or "Hey Prajwal, Aegis detected high stress. Take a breath. You've got this.",
                voice="Polly.Joanna"
            )
            twiml = str(vr)

        client = TwilioClient(TWILIO_SID, TWILIO_AUTH)
        call = await asyncio.to_thread(
            client.calls.create,
            to=CALL_TARGET,
            from_=TWILIO_NUMBER,
            twiml=twiml,
        )
        print(f"📞 Twilio call initiated: {call.sid}")
        return {"status": "initiated", "sid": call.sid}
    except Exception as e:
        print(f"Twilio error: {e}")
        return {"status": "error", "reason": str(e)}

# ─────────────────────────────────────────────────────────
# Core intervention pipeline
# ─────────────────────────────────────────────────────────
async def run_intervention_pipeline(au_data: dict, active_app: str | None = None):
    if active_app is None:
        active_app = await asyncio.to_thread(get_active_app)

    gemini_result = await run_gemini_reasoning(au_data, active_app)

    # Twilio call if Gemini decides it's needed
    call_result = {"status": "not_triggered"}
    if gemini_result.get("trigger_call") and gemini_result.get("stress_level") == "HIGH":
        call_result = await make_twilio_call(gemini_result.get("twiml_script", ""))

    payload = {
        **gemini_result,
        "au_data": au_data,
        "active_app": active_app,
        "call_result": call_result,
    }

    # Emit to all React clients
    await sio.emit("intervention", payload)

    # Persist to MongoDB
    await log_intervention(au_data, gemini_result, active_app, call_result.get("status") == "initiated")

    return payload

# ─────────────────────────────────────────────────────────
# REST Endpoints
# ─────────────────────────────────────────────────────────
MOCK_USER = {
    "name": "Prajwal", "cgpa": 9.0,
    "interests": ["React", "ML", "E-Sports", "AI"],
    "role": "Professional Gamer / ML Engineer",
    "recovery_score": 87, "blink_normalization": 76,
    "sessions_today": 4, "tilt_events_avoided": 12,
}

@app.get("/api/user")
async def get_user():
    if db is not None:
        try:
            user = await db["users"].find_one({"name": "Prajwal"}, {"_id": 0})
            if user:
                return JSONResponse(content=user)
        except Exception as e:
            print(f"DB read error: {e}")
    return JSONResponse(content=MOCK_USER)

@app.get("/api/interventions")
async def get_interventions():
    """Return last 20 logged interventions for the history tab."""
    if db is None:
        return JSONResponse(content={"interventions": []})
    try:
        cursor = db["interventions"].find({}, {"_id": 0}).sort("timestamp", -1).limit(20)
        docs = await cursor.to_list(length=20)
        for d in docs:
            if isinstance(d.get("timestamp"), datetime.datetime):
                d["timestamp"] = d["timestamp"].isoformat()
        return JSONResponse(content={"interventions": docs})
    except Exception as e:
        return JSONResponse(content={"interventions": [], "error": str(e)})

@app.get("/api/active-app")
async def active_app_endpoint():
    """Let the frontend poll the currently focused window."""
    app_name = await asyncio.to_thread(get_active_app)
    return {"active_app": app_name}

@app.post("/trigger-stress")
async def trigger_stress():
    """
    Hackathon demo trigger: auto-detects active window, calls Gemini,
    optionally calls Twilio, emits intervention event.
    """
    mock_au = {"au4": 0.85, "au23": 0.90, "blink_rate": 6}
    active_app = await asyncio.to_thread(get_active_app)
    payload = await run_intervention_pipeline(mock_au, active_app)
    return JSONResponse(content={"status": "stress_triggered", "payload": payload})

@app.post("/trigger-elevated")
async def trigger_elevated():
    """Trigger ELEVATED (not HIGH) for softer demo."""
    mock_au = {"au4": 0.55, "au23": 0.55, "blink_rate": 11}
    active_app = await asyncio.to_thread(get_active_app)
    payload = await run_intervention_pipeline(mock_au, active_app)
    return JSONResponse(content={"status": "elevated_triggered", "payload": payload})

@app.post("/reset-stress")
async def reset_stress():
    await sio.emit("intervention", {
        "stress_level": "STABLE", "action": "NONE", "level": "NONE",
        "confidence": 1.0, "reasoning": "Manual reset triggered.",
        "toast_msg": "System reset. You're clear.", "toast_emoji": "✅",
        "intervention_tip": "System reset. You're clear.",
        "trigger_call": False, "source": "reset",
    })
    return JSONResponse(content={"status": "reset"})

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "Aegis.ai Backend v2",
        "model": "gemini-2.5-flash",
        "twilio": "configured" if TWILIO_SID else "not_configured",
    }

# ─────────────────────────────────────────────────────────
# Socket.IO Events
# ─────────────────────────────────────────────────────────
@sio.event
async def connect(sid, environ):
    print(f"🔌 Client connected: {sid}")
    active_app = await asyncio.to_thread(get_active_app)
    await sio.emit("connected", {
        "message": "Aegis.ai backend v2 online",
        "sid": sid,
        "active_app": active_app,
    }, to=sid)

@sio.event
async def disconnect(sid):
    print(f"❌ Client disconnected: {sid}")

@sio.event
async def au_metadata(sid, data):
    """Live AU stream from React slider panel or YOLOv8 service."""
    print(f"📊 AU metadata from {sid}: {data}")
    try:
        au_data = {
            "au4":        float(data.get("au4", 0)),
            "au23":       float(data.get("au23", 0)),
            "blink_rate": int(data.get("blink_rate", 15)),
        }
        active_app = data.get("active_app") or await asyncio.to_thread(get_active_app)
        await run_intervention_pipeline(au_data, active_app)
    except Exception as e:
        print(f"Error in au_metadata: {e}")
        await sio.emit("error", {"message": str(e)}, to=sid)
