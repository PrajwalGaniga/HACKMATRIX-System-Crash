import re
import sys

def main():
    try:
        with open('c:/Users/ASUS/Desktop/Projects/HackMatrix/backend/main.py', 'r', encoding='utf-8') as f:
            content = f.read()

        # 1. Imports
        imports = """
import jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status, Form
from fastapi.security import OAuth2PasswordBearer
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
"""
        content = content.replace("from fastapi.responses import JSONResponse", "from fastapi.responses import JSONResponse\n" + imports)

        # 2. Add auth setup and templates after FastAPI setup
        auth_setup = """
# ─────────────────────────────────────────────────────────
# Auth & Templates Setup
# ─────────────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/login")
SECRET_KEY = os.getenv("SECRET_KEY", "aegis_hackathon_secret_123")
ALGORITHM = "HS256"

templates = Jinja2Templates(directory="templates")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta=None):
    to_encode = data.copy()
    expire = datetime.datetime.utcnow() + (expires_delta or datetime.timedelta(days=7))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        phone: str = payload.get("sub")
        if phone is None:
            raise credentials_exception
    except jwt.PyJWTError:
        raise credentials_exception
        
    if db is not None:
        user = await db["users"].find_one({"phone": phone})
        if user is None:
            raise credentials_exception
        return user
    else:
        # Fallback mock user if no DB
        if phone == "+1234567890":
            return MOCK_USER
        raise credentials_exception
"""
        content = content.replace("# ─────────────────────────────────────────────────────────\n# MongoDB\n# ─────────────────────────────────────────────────────────", auth_setup + "\n# ─────────────────────────────────────────────────────────\n# MongoDB\n# ─────────────────────────────────────────────────────────")

        # 3. Update startup seeded user
        startup_seeded = """        existing = await users_col.find_one({"phone": "+1234567890"})
        if not existing:
            await users_col.insert_one({
                "name": "Prajwal",
                "phone": "+1234567890",
                "hashed_password": get_password_hash("password123"),
                "guardian_phone": "+919110687983",
                "cgpa": 9.0,
                "interests": ["React", "ML", "E-Sports", "AI"],
                "role": "Professional Gamer / ML Engineer",
                "recovery_score": 87,
                "blink_normalization": 76,
                "sessions_today": 4,
                "tilt_events_avoided": 12,
            })"""
        content = re.sub(r'        existing = await users_col\.find_one\(\{"name": "Prajwal"\}\).*?tilt_events_avoided": 12,\n            \}\)', startup_seeded, content, flags=re.DOTALL)

        # 4. Auth endpoints
        auth_routes = """
@app.get("/", response_class=HTMLResponse)
async def serve_index(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.get("/login", response_class=HTMLResponse)
async def serve_login(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.get("/dashboard", response_class=HTMLResponse)
async def serve_dashboard(request: Request):
    return templates.TemplateResponse("dashboard.html", {"request": request})

@app.post("/api/signup")
async def signup(request: Request):
    data = await request.json()
    if db is not None:
        existing = await db["users"].find_one({"phone": data.get("phone")})
        if existing:
            raise HTTPException(status_code=400, detail="Phone number already registered")
        user_dict = {
            "name": data.get("name"),
            "phone": data.get("phone"),
            "hashed_password": get_password_hash(data.get("password")),
            "guardian_phone": data.get("guardian_phone", ""),
            "recovery_score": 85,
            "tilt_events_avoided": 0,
            "role": "User"
        }
        await db["users"].insert_one(user_dict)
        access_token = create_access_token(data={"sub": user_dict["phone"]})
        return {"access_token": access_token, "token_type": "bearer"}
    return {"error": "DB unavailable"}

@app.post("/api/login")
async def login(request: Request):
    data = await request.json()
    if db is not None:
        user = await db["users"].find_one({"phone": data.get("phone")})
        if not user or not verify_password(data.get("password"), user["hashed_password"]):
            raise HTTPException(status_code=401, detail="Incorrect phone or password")
        access_token = create_access_token(data={"sub": user["phone"]})
        return {"access_token": access_token, "token_type": "bearer"}
    else:
        # Fallback
        if data.get("phone") == "+1234567890" and data.get("password") == "password123":
            access_token = create_access_token(data={"sub": "+1234567890"})
            return {"access_token": access_token, "token_type": "bearer"}
        raise HTTPException(status_code=401, detail="Incorrect credentials (Mock)")

@app.post("/api/update-guardian")
async def update_guardian(request: Request, current_user: dict = Depends(get_current_user)):
    data = await request.json()
    new_guardian = data.get("guardian_phone")
    if db is not None and new_guardian:
        await db["users"].update_one(
            {"phone": current_user["phone"]},
            {"$set": {"guardian_phone": new_guardian}}
        )
        return {"status": "ok", "guardian_phone": new_guardian}
    return {"status": "error"}

@app.post("/api/sos-alert")
async def trigger_sos_alert(current_user: dict = Depends(get_current_user)):
    guardian_phone = current_user.get("guardian_phone")
    if not guardian_phone:
        return {"status": "error", "reason": "no_guardian_configured"}
    
    twiml = f"<Response><Say voice='Polly.Joanna'>Emergency Alert from Aegis. {current_user.get('name', 'Your ward')} may have experienced a fall or serious impact. Please check on them immediately.</Say></Response>"
    
    # Actually call them
    if not TWILIO_SID or not TWILIO_AUTH:
        print(f"⚠️ Fake Twilio call to {guardian_phone} for {current_user.get('name')}")
        return {"status": "simulated", "guardian_phone": guardian_phone}
        
    from twilio.rest import Client as TwilioClient
    client = TwilioClient(TWILIO_SID, TWILIO_AUTH)
    try:
        call = await asyncio.to_thread(
            client.calls.create,
            to=guardian_phone,
            from_=TWILIO_NUMBER,
            twiml=twiml,
        )
        print(f"📞 SOS Twilio call initiated to {guardian_phone}: {call.sid}")
        return {"status": "initiated", "sid": call.sid}
    except Exception as e:
        print(f"SOS Twilio error: {e}")
        return {"status": "error", "reason": str(e)}
"""
        content = content.replace("MOCK_USER = {", auth_routes + "\n\n" + "MOCK_USER = {")

        # 5. Fix /api/user mapping
        api_user_fixed = """@app.get("/api/user")
async def get_user(current_user: dict = Depends(get_current_user)):
    # Need to return user dict, safely popping password
    safe_user = dict(current_user)
    safe_user.pop("_id", None)
    safe_user.pop("hashed_password", None)
    return JSONResponse(content=safe_user)"""
        content = re.sub(r'@app\.get\("/api/user"\)\nasync def get_user\(\):\n.*?return JSONResponse\(content=MOCK_USER\)', api_user_fixed, content, flags=re.DOTALL)
        
        # Write back
        with open('c:/Users/ASUS/Desktop/Projects/HackMatrix/backend/main.py', 'w', encoding='utf-8') as f:
            f.write(content)
            
        print("Successfully updated main.py")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    main()
