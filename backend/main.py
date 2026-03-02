import asyncio
import os
import json
import datetime
import base64
import socketio
import numpy as np
from fastapi import FastAPI, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from motor.motor_asyncio import AsyncIOMotorClient
import google.generativeai as genai
from dotenv import load_dotenv

# ML imports
import cv2
try:
    from ultralytics import YOLO
except ImportError:
    YOLO = None

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
    allow_origins=["*"],
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
# YOLOv8 — Background Webcam Inference Task
# ─────────────────────────────────────────────────────────
ml_active = False
ml_task = None
yolo_model = None
blink_timestamps = []

FALLBACK_STRESS_PATH = "fallback_stress.json"
FALLBACK_TIMEOUT_SECS = 30

def _load_fallback_data() -> dict:
    try:
        with open(FALLBACK_STRESS_PATH) as f:
            return json.load(f)
    except Exception:
        return {"au4": 0.82, "au7": 0.61, "au23": 0.88, "au43": 0.15, "blink_rate": 7, "source": "fallback"}

def _run_yolo_on_frame(frame) -> dict:
    """Run YOLO inference on a single BGR frame. Returns raw AU dict."""
    if yolo_model is None:
        return {}
    try:
        results = yolo_model.predict(source=frame, conf=0.25, imgsz=640, verbose=False)
        au_data = {"au4": 0.0, "au7": 0.0, "au23": 0.0, "au43": 0.0}
        any_detected = False
        for r in results:
            for box in r.boxes:
                cls_id = int(box.cls[0])
                score = float(box.conf[0])
                any_detected = True
                if cls_id == 0: au_data["au4"] = max(au_data["au4"], score)
                elif cls_id == 1: au_data["au7"] = max(au_data["au7"], score)
                elif cls_id == 2: au_data["au23"] = max(au_data["au23"], score)
                elif cls_id == 3: au_data["au43"] = max(au_data["au43"], score)
        au_data["_detected"] = any_detected
        return au_data
    except Exception as e:
        print(f"YOLO inference error: {e}")
        return {}

MODEL_PATH = "ml_model/best1.onnx"
consecutive_fail_count = 0
FAIL_SAFE_THRESHOLD = 3  # 3 consecutive failures before force-inject
_force_stress_task = None

async def _emit_forced_stress(reason: str = "model_failure"):
    """Force-inject HIGH stress when the model fails to load or detect faces."""
    active_app = await asyncio.to_thread(get_active_app)
    forced_payload = {
        "au4": 0.82, "au7": 0.71, "au23": 0.95, "au43": 0.10,
        "blink_rate": 5, "timestamp": datetime.datetime.now().timestamp(),
        "source": "fail_safe", "reason": reason,
    }
    # Emit telemetry so dashboard shows AU bars spiking
    await sio.emit("ml_telemetry", forced_payload)
    print(f"🚨 Fail-Safe triggered ({reason}) — force-injecting HIGH stress")
    # Run full Gemini + Twilio intervention pipeline
    asyncio.create_task(run_intervention_pipeline(forced_payload, active_app))
    # Log to MongoDB
    if db is not None:
        try:
            await db["interventions"].insert_one({
                "timestamp": datetime.datetime.utcnow(),
                "active_app": active_app,
                "source": "fail_safe",
                "reason": reason,
                "stress_level": "HIGH",
            })
        except Exception:
            pass

async def run_yolo_stream():
    global ml_active, yolo_model, blink_timestamps, consecutive_fail_count
    if YOLO is None:
        print("⚠️ Ultralytics not installed — activating fail-safe stress mode.")
        await _emit_forced_stress("ultralytics_missing")
        return
    if not yolo_model:
        try:
            yolo_model = YOLO(MODEL_PATH, task="detect")
            print(f"✅ YOLO model loaded: {MODEL_PATH}")
        except Exception as e:
            print(f"⚠️ Failed to load ONNX model: {e}")
            print("🚨 Activating fail-safe: will inject HIGH stress every 30s")
            # Immediately inject and then loop every 30s
            await _emit_forced_stress(f"model_load_failed: {e}")
            while ml_active:
                await asyncio.sleep(30)
                if ml_active:
                    await _emit_forced_stress("periodic_fail_safe")
            return

    cap = cv2.VideoCapture(0)
    print("🎥 Aegis ML Vision Engine started...")
    last_intervention_time = 0
    last_detection_time = datetime.datetime.now().timestamp()

    while ml_active:
        ret, frame = cap.read()
        if not ret:
            await asyncio.sleep(0.1)
            continue

        au_data = await asyncio.to_thread(_run_yolo_on_frame, frame)
        now = datetime.datetime.now().timestamp()
        source = "yolo"

        # ── 30s Fallback Logic ──────────────────────────────────
        if au_data.get("_detected"):
            last_detection_time = now
        elif (now - last_detection_time) > FALLBACK_TIMEOUT_SECS:
            print(f"⚠️ No face detected for {FALLBACK_TIMEOUT_SECS}s — loading fallback_stress.json")
            fb = _load_fallback_data()
            au_data = {k: v for k, v in fb.items() if k != "_comment"}
            source = "fallback"

        au_data.pop("_detected", None)

        # ── Blink Rate from AU43 ────────────────────────────────
        if au_data.get("au43", 0) > 0.4:
            if not blink_timestamps or (now - blink_timestamps[-1]) > 0.4:
                blink_timestamps.append(now)
        blink_timestamps = [t for t in blink_timestamps if now - t <= 60]
        if len(blink_timestamps) < 2:
            bpm = 15
        else:
            span = max(1.0, now - blink_timestamps[0])
            bpm = int((len(blink_timestamps) / span) * 60)
        bpm = max(5, min(bpm, 40))

        payload = {
            "au4": au_data.get("au4", 0.0),
            "au7": au_data.get("au7", 0.0),
            "au23": au_data.get("au23", 0.0),
            "au43": au_data.get("au43", 0.0),
            "blink_rate": au_data.get("blink_rate", bpm),
            "timestamp": now,
            "source": source,
        }

        await sio.emit("ml_telemetry", payload)

        if (payload["au23"] > 0.7 or payload["blink_rate"] < 8) and (now - last_intervention_time > 30):
            last_intervention_time = now
            active_app = await asyncio.to_thread(get_active_app)
            asyncio.create_task(run_intervention_pipeline(payload, active_app))

        await asyncio.sleep(0.08)

    cap.release()
    print("🛑 Aegis ML Vision Engine stopped.")

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
3. Pick the BEST primary game AND 2 backup options for this context:
   - High cognitive load/racing thoughts → primary: "MINDFUL_PUZZLE", backups: ["BREATHING_TRAINER", "IDLE_GARDEN"]
   - Angry/frustrated/tilt → primary: "BUBBLE_WRAP", backups: ["BREATHING_TRAINER", "RELAXING_COLORING"]
   - Fast heart rate/panic → primary: "BREATHING_TRAINER", backups: ["IDLE_GARDEN", "BUBBLE_WRAP"]
   - Overwhelmed/stuck → primary: "RELAXING_COLORING", backups: ["MINDFUL_PUZZLE", "IDLE_GARDEN"]
   - General burnout/mild stress → primary: "IDLE_GARDEN", backups: ["RELAXING_COLORING", "BREATHING_TRAINER"]
4. Generate breathing_tip: a 4-7-8 or box breathing instruction, 1 sentence, warm tone.
5. Generate rest_reminder: friendly nudge to hydrate/stand/look away, 1 sentence.
6. TwiML for Polly.Joanna voice call — script MUST sound extremely natural, start with a warm greeting ("Hey Prajwal..."), offer brief, empathetic motivation based on the context, and END GENTLY and professionally ("...take care, I've got your back. Bye."). Max 3 sentences. Trigger ONLY on HIGH.

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
  "game_options": ["PRIMARY_GAME", "BACKUP_1", "BACKUP_2"],
  "cta_label": "Take a 60s Break",
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

last_processed_time = 0.0
infer_miss_count = 0

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

@app.post("/api/toggle-ml")
async def toggle_ml(request: Request):
    """Start or stop the YOLOv8 webcam inference loop."""
    global ml_active, ml_task
    data = await request.json()
    enable = data.get("active", False)
    
    ml_active = enable
    if ml_active and (ml_task is None or ml_task.done()):
        ml_task = asyncio.create_task(run_yolo_stream())
        
    return JSONResponse(content={"status": "ok", "ml_active": ml_active})

@app.post("/api/infer-frame")
async def infer_frame(request: Request):
    """
    Accept a base64-encoded PNG/JPEG frame from the React browser webcam canvas.
    Run YOLO inference and return AU scores. Emits ml_telemetry via Socket.IO.
    """
    try:
        data = await request.json()
        b64 = data.get("image_b64", "")
        # Strip data URL prefix if present
        if "," in b64:
            b64 = b64.split(",", 1)[1]
        img_bytes = base64.b64decode(b64)
        nparr = np.frombuffer(img_bytes, dtype=np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if frame is None:
            return JSONResponse(content={"error": "Could not decode image"}, status_code=400)

        # Ensure model is loaded (lazy load for browser endpoint)
        global yolo_model
        if yolo_model is None and YOLO is not None:
            try:
                yolo_model = YOLO(MODEL_PATH, task="detect")
                print(f"✅ YOLO lazy-loaded for browser endpoint: {MODEL_PATH}")
            except Exception as e:
                # Fail-safe: return mocked HIGH-stress AU if model fails
                print(f"⚠️ infer-frame model load failed: {e} — using fail-safe values")
                now2 = datetime.datetime.now().timestamp()
                fs = {"au4": 0.82, "au7": 0.71, "au23": 0.95, "au43": 0.10, "blink_rate": 5, "timestamp": now2, "source": "fail_safe"}
                await sio.emit("ml_telemetry", fs)
                asyncio.create_task(run_intervention_pipeline(fs, await asyncio.to_thread(get_active_app)))
                return JSONResponse(content=fs)

        au_data = await asyncio.to_thread(_run_yolo_on_frame, frame)
        detected = au_data.pop("_detected", False)
        now = datetime.datetime.now().timestamp()

        # ── Model Fallback Logic (6s / 3 misses) ────────────────
        if not detected:
            infer_miss_count += 1
            if infer_miss_count >= 3:
                print(f"⚠️ No face detected for 3 consecutive samples ({infer_miss_count * 2}s) — using fallback_stress.json")
                fb = _load_fallback_data()
                fs = {k: v for k, v in fb.items() if k != "_comment"}
                fs["timestamp"] = now
                fs["source"] = "fallback"
                await sio.emit("ml_telemetry", fs)
                asyncio.create_task(run_intervention_pipeline(fs, await asyncio.to_thread(get_active_app)))
                return JSONResponse(content=fs)
        else:
            infer_miss_count = 0

        # Estimate blink rate (simplified for single-frame analysis)
        bpm = 15 if au_data.get("au43", 0) < 0.4 else 10

        payload = {**au_data, "blink_rate": bpm, "timestamp": now, "source": "browser_webcam"}
        await sio.emit("ml_telemetry", payload)
        return JSONResponse(content=payload)
    except Exception as e:
        print(f"/api/infer-frame error: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.post("/api/upload-frame")
async def upload_frame(file: UploadFile = File(...)):
    """
    Accept a multipart image upload for instant testing.
    Rate-limited to 1 frame every 2 seconds.
    """
    global last_processed_time, infer_miss_count, yolo_model
    now_ms = datetime.datetime.now().timestamp()
    if now_ms - last_processed_time < 2.0:
        return JSONResponse(content={"status": "skipped", "reason": "rate_limit_active"})
    
    last_processed_time = now_ms

    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, dtype=np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if frame is None:
            return JSONResponse(content={"error": "Cannot decode image"}, status_code=400)

        global yolo_model
        if yolo_model is None and YOLO is not None:
            try:
                yolo_model = YOLO(MODEL_PATH, task="detect")
            except Exception as e:
                return JSONResponse(content={"error": f"Model load failed: {e}"}, status_code=500)

        au_data = await asyncio.to_thread(_run_yolo_on_frame, frame)
        au_data.pop("_detected", None)

        now = datetime.datetime.now().timestamp()
        bpm = 15 if au_data.get("au43", 0) < 0.4 else 10
        payload = {**au_data, "blink_rate": bpm, "timestamp": now, "source": "file_upload"}
        await sio.emit("ml_telemetry", payload)

        # Auto-run a quick Gemini intervention analysis on this upload
        active_app = await asyncio.to_thread(get_active_app)
        payload_with_meta = {**payload, "au4": payload.get("au4", 0), "au23": payload.get("au23", 0)}
        asyncio.create_task(run_intervention_pipeline(payload_with_meta, active_app))

        return JSONResponse(content={"status": "ok", "au_data": payload, "message": "Inference complete. Check debug log for Gemini response."})
    except Exception as e:
        print(f"/api/upload-frame error: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)


@app.get("/health")
async def health_check():
    """Used by React dashboard to check backend status and ML state."""
    return JSONResponse(content={
        "status": "ok",
        "ml_active": ml_active,
        "model_loaded": yolo_model is not None,
        "model_path": MODEL_PATH,
        "timestamp": datetime.datetime.utcnow().isoformat(),
    })

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
