"""
Общий backend экосистемы STAW — walking skeleton (Auth + Loyalty).

Реализует часть контракта ECOSYSTEM_API.md:
  POST /v1/auth/register        {name,email,password} -> {token, user}
  POST /v1/auth/login           {email,password}      -> {token, user}
  GET  /v1/auth/me                                    -> user           (Bearer)
  GET  /v1/loyalty/account                            -> {balance,level,transactions}  (Bearer)
  POST /v1/loyalty/transactions LoyaltyTransaction    -> {ok:true}      (Bearer)
  GET  /v1/health                                     -> {status:"ok"}

Стек: FastAPI + стандартная библиотека (sqlite3, hmac, hashlib). Без компилируемых
зависимостей — запускается на любом Python 3.10+. БД — SQLite (для dev). Для прод —
заменить на PostgreSQL (одна точка: connect()).

Запуск:  python -m uvicorn main:app --host 0.0.0.0 --port 8000
"""
import base64
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
import time
from datetime import datetime, timezone

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ─── Конфиг ───────────────────────────────────────────────────────────────────
DB_PATH = os.path.join(os.path.dirname(__file__), "ecosystem.db")
JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret-change-in-prod")
JWT_TTL = 60 * 60 * 24 * 30  # 30 дней

app = FastAPI(title="STAW Ecosystem API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
)


# ─── БД ───────────────────────────────────────────────────────────────────────
def connect():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    return con


def init_db():
    con = connect()
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            name TEXT, email TEXT UNIQUE, phone TEXT,
            provider TEXT DEFAULT 'email',
            avatar_path TEXT,
            password_hash TEXT,
            created_at TEXT
        );
        CREATE TABLE IF NOT EXISTS loyalty_transactions (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            amount INTEGER,
            source TEXT,
            description TEXT,
            order_id TEXT,
            run_id TEXT,
            created_at TEXT
        );
        """
    )
    columns = {row[1] for row in con.execute("PRAGMA table_info(users)").fetchall()}
    if "city" not in columns:
        con.execute("ALTER TABLE users ADD COLUMN city TEXT")
    con.commit()
    con.close()


init_db()


# ─── Утилиты: пароль, JWT (stdlib) ────────────────────────────────────────────
def hash_password(password: str, salt: str | None = None) -> str:
    salt = salt or secrets.token_hex(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 100_000)
    return f"{salt}${dk.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        salt, _ = stored.split("$", 1)
    except ValueError:
        return False
    return hmac.compare_digest(stored, hash_password(password, salt))


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def make_token(user_id: str) -> str:
    header = _b64url(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    payload = _b64url(json.dumps({"sub": user_id, "exp": int(time.time()) + JWT_TTL}).encode())
    signing_input = f"{header}.{payload}".encode()
    sig = _b64url(hmac.new(JWT_SECRET.encode(), signing_input, hashlib.sha256).digest())
    return f"{header}.{payload}.{sig}"


def user_id_from_token(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Нет токена")
    token = authorization.split(" ", 1)[1]
    try:
        header, payload, sig = token.split(".")
        expected = _b64url(
            hmac.new(JWT_SECRET.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest()
        )
        if not hmac.compare_digest(sig, expected):
            raise ValueError("bad signature")
        data = json.loads(base64.urlsafe_b64decode(payload + "=="))
        if data.get("exp", 0) < time.time():
            raise ValueError("expired")
        return data["sub"]
    except Exception:
        raise HTTPException(401, "Невалидный токен")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_phone(phone: str) -> str:
    digits = ''.join(ch for ch in phone if ch.isdigit())
    if len(digits) == 10:
        digits = '7' + digits
    if len(digits) == 11 and digits.startswith('8'):
        digits = '7' + digits[1:]
    return f'+{digits}' if digits else phone.strip()


def synthetic_email_for_phone(phone: str) -> str:
    digits = ''.join(ch for ch in phone if ch.isdigit())
    return f'runner_{digits}@kvartal.local'


# ─── Сериализация ─────────────────────────────────────────────────────────────
def user_json(row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "email": row["email"],
        "phone": row["phone"],
        "city": row["city"] if "city" in row.keys() else None,
        "provider": row["provider"] or "email",
        "avatarPath": row["avatar_path"],
        "addresses": [],
    }


def txn_json(row) -> dict:
    return {
        "id": row["id"],
        "amount": row["amount"],
        "source": row["source"],
        "description": row["description"],
        "orderId": row["order_id"],
        "createdAt": row["created_at"],
    }


def level_for(balance: int) -> str:
    if balance >= 1000: return "platinum"
    if balance >= 500:  return "gold"
    if balance >= 200:  return "silver"
    return "basic"


def add_txn(con, user_id, amount, source, description, order_id=None, run_id=None):
    con.execute(
        "INSERT INTO loyalty_transactions (id,user_id,amount,source,description,order_id,run_id,created_at)"
        " VALUES (?,?,?,?,?,?,?,?)",
        (f"tx_{secrets.token_hex(8)}", user_id, amount, source, description, order_id, run_id, now_iso()),
    )


def seed_runner_points(con, user_id):
    """Имитация баллов, заработанных в Runner App «Квартал» (для демо экосистемы)."""
    demo = [
        (20, "registration", "Бонус за регистрацию"),
        (120, "runnerRun", "Пробежка 12.0 км"),
        (50, "runnerTerritory", "Захват территории: ул. Спортивная"),
        (200, "runnerCompetition", "Победа в забеге «Весенний круг»"),
        (40, "runnerRun", "Пробежка 4.0 км"),
    ]
    for amount, source, desc in demo:
        add_txn(con, user_id, amount, source, desc)


# ─── Схемы запросов ───────────────────────────────────────────────────────────
class RegisterIn(BaseModel):
    name: str
    email: str
    password: str
    phone: str | None = None


class LoginIn(BaseModel):
    email: str
    password: str


class PhoneVerifyIn(BaseModel):
    phone: str
    code: str
    name: str | None = None


class ProfileUpdateIn(BaseModel):
    name: str | None = None
    phone: str | None = None
    email: str | None = None
    city: str | None = None
    avatarPath: str | None = None


class TxnIn(BaseModel):
    amount: int
    source: str
    description: str = ""
    orderId: str | None = None
    runId: str | None = None


# ─── Эндпоинты ────────────────────────────────────────────────────────────────
@app.get("/v1/health")
def health():
    return {"status": "ok", "service": "staw-ecosystem", "time": now_iso()}


@app.post("/v1/auth/register")
def register(body: RegisterIn):
    con = connect()
    exists = con.execute("SELECT 1 FROM users WHERE email=?", (body.email.lower(),)).fetchone()
    if exists:
        con.close()
        raise HTTPException(409, "Пользователь с таким email уже существует")
    uid = f"u_{secrets.token_hex(8)}"
    con.execute(
        "INSERT INTO users (id,name,email,phone,provider,password_hash,created_at)"
        " VALUES (?,?,?,?,?,?,?)",
        (uid, body.name.strip(), body.email.lower().strip(), body.phone, "email",
         hash_password(body.password), now_iso()),
    )
    seed_runner_points(con, uid)  # демо: баллы «из Квартала»
    con.commit()
    row = con.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
    con.close()
    return {"token": make_token(uid), "user": user_json(row)}


@app.post("/v1/auth/login")
def login(body: LoginIn):
    con = connect()
    row = con.execute("SELECT * FROM users WHERE email=?", (body.email.lower().strip(),)).fetchone()
    con.close()
    if not row or not verify_password(body.password, row["password_hash"] or ""):
        raise HTTPException(401, "Неверный email или пароль")
    return {"token": make_token(row["id"]), "user": user_json(row)}


@app.post("/v1/auth/phone/verify")
def phone_verify(body: PhoneVerifyIn):
    if body.code != "1234":
        raise HTTPException(401, "Invalid verification code")

    phone = normalize_phone(body.phone)
    email = synthetic_email_for_phone(phone)
    con = connect()

    row = con.execute("SELECT * FROM users WHERE phone=?", (phone,)).fetchone()
    if not row:
        row = con.execute("SELECT * FROM users WHERE email=?", (email,)).fetchone()
        if row:
            con.execute("UPDATE users SET phone=? WHERE id=?", (phone, row["id"]))
            con.commit()
            row = con.execute("SELECT * FROM users WHERE id=?", (row["id"],)).fetchone()

    if not row:
        uid = f"u_{secrets.token_hex(8)}"
        con.execute(
            "INSERT INTO users (id,name,email,phone,provider,password_hash,created_at)"
            " VALUES (?,?,?,?,?,?,?)",
            (uid, (body.name or "Runner").strip(), email, phone, "phone",
             hash_password(f"phone:{phone}"), now_iso()),
        )
        seed_runner_points(con, uid)
        con.commit()
        row = con.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()

    con.close()
    return {"token": make_token(row["id"]), "user": user_json(row)}


@app.get("/v1/auth/me")
def me(authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    row = con.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
    con.close()
    if not row:
        raise HTTPException(404, "Пользователь не найден")
    return user_json(row)


@app.patch("/v1/profile")
def update_profile(body: ProfileUpdateIn, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    updates = []
    values = []

    if body.name is not None:
        name = body.name.strip()
        if not name:
            raise HTTPException(400, "Name cannot be empty")
        updates.append("name=?")
        values.append(name)
    if body.phone is not None:
        updates.append("phone=?")
        values.append(normalize_phone(body.phone))
    if body.email is not None:
        email = body.email.lower().strip()
        if email and "@" not in email:
            raise HTTPException(400, "Invalid email")
        updates.append("email=?")
        values.append(email or None)
    if body.city is not None:
        updates.append("city=?")
        values.append(body.city.strip() or None)
    if body.avatarPath is not None:
        updates.append("avatar_path=?")
        values.append(body.avatarPath.strip() or None)

    con = connect()
    if updates:
        try:
            con.execute(f"UPDATE users SET {', '.join(updates)} WHERE id=?", (*values, uid))
            con.commit()
        except sqlite3.IntegrityError:
            con.close()
            raise HTTPException(409, "Email already belongs to another account")

    row = con.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
    con.close()
    if not row:
        raise HTTPException(404, "User not found")
    return user_json(row)


@app.get("/v1/loyalty/account")
def loyalty_account(authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    rows = con.execute(
        "SELECT * FROM loyalty_transactions WHERE user_id=? ORDER BY created_at DESC", (uid,)
    ).fetchall()
    con.close()
    balance = sum(r["amount"] for r in rows)
    return {
        "balance": balance,
        "level": level_for(balance),
        "transactions": [txn_json(r) for r in rows],
    }


@app.post("/v1/loyalty/transactions")
def loyalty_post(body: TxnIn, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    # Идемпотентность: одно начисление за (пользователь, runId, source).
    # Защищает от двойного начисления при повторной отправке из офлайн-очереди.
    if body.runId:
        existing = con.execute(
            "SELECT 1 FROM loyalty_transactions WHERE user_id=? AND run_id=? AND source=?",
            (uid, body.runId, body.source),
        ).fetchone()
        if existing:
            con.close()
            return {"ok": True, "deduped": True}
    add_txn(con, uid, body.amount, body.source, body.description, body.orderId, body.runId)
    con.commit()
    con.close()
    return {"ok": True}
