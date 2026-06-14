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
from datetime import datetime, timedelta, timezone

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
        CREATE TABLE IF NOT EXISTS clubs (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            logo TEXT,
            city TEXT,
            description TEXT,
            owner_id TEXT NOT NULL,
            join_policy TEXT DEFAULT 'open',   -- 'open' | 'request'
            created_at TEXT
        );
        CREATE TABLE IF NOT EXISTS club_members (
            club_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            role TEXT DEFAULT 'member',        -- 'owner' | 'member'
            joined_at TEXT,
            PRIMARY KEY (club_id, user_id)
        );
        -- один клуб на человека (на уровне БД)
        CREATE UNIQUE INDEX IF NOT EXISTS idx_one_club_per_user
            ON club_members(user_id);
        CREATE TABLE IF NOT EXISTS club_join_requests (
            id TEXT PRIMARY KEY,
            club_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            status TEXT DEFAULT 'pending',     -- 'pending' | 'approved' | 'rejected'
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


class ClubCreateIn(BaseModel):
    name: str
    logo: str | None = None
    city: str | None = None
    description: str | None = None
    joinPolicy: str = "open"  # 'open' | 'request'


class ClubUpdateIn(BaseModel):
    name: str | None = None
    logo: str | None = None
    city: str | None = None
    description: str | None = None
    joinPolicy: str | None = None


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


# ─── Клубы ──────────────────────────────────────────────────────────────────
def user_balance(con, uid) -> int:
    r = con.execute(
        "SELECT COALESCE(SUM(amount),0) b FROM loyalty_transactions WHERE user_id=?",
        (uid,),
    ).fetchone()
    return r["b"]


def current_club_id(con, uid):
    r = con.execute("SELECT club_id FROM club_members WHERE user_id=?", (uid,)).fetchone()
    return r["club_id"] if r else None


def club_members_json(con, club_id) -> list:
    rows = con.execute(
        "SELECT m.user_id, m.role, u.name FROM club_members m "
        "JOIN users u ON u.id=m.user_id WHERE m.club_id=?",
        (club_id,),
    ).fetchall()
    out = [
        {"userId": r["user_id"], "name": r["name"], "role": r["role"],
         "points": user_balance(con, r["user_id"])}
        for r in rows
    ]
    out.sort(key=lambda x: x["points"], reverse=True)
    return out


def club_summary_json(con, row) -> dict:
    members = con.execute(
        "SELECT user_id FROM club_members WHERE club_id=?", (row["id"],)
    ).fetchall()
    return {
        "id": row["id"], "name": row["name"], "logo": row["logo"], "city": row["city"],
        "description": row["description"], "ownerId": row["owner_id"],
        "joinPolicy": row["join_policy"], "memberCount": len(members),
        "totalPoints": sum(user_balance(con, m["user_id"]) for m in members),
    }


def club_detail_json(con, row, uid) -> dict:
    base = club_summary_json(con, row)
    base["members"] = club_members_json(con, row["id"])
    myrole = con.execute(
        "SELECT role FROM club_members WHERE club_id=? AND user_id=?", (row["id"], uid)
    ).fetchone()
    base["myRole"] = myrole["role"] if myrole else None
    return base


@app.get("/v1/clubs")
def list_clubs(search: str | None = None, authorization: str | None = Header(default=None)):
    user_id_from_token(authorization)
    con = connect()
    if search:
        like = f"%{search}%"
        rows = con.execute(
            "SELECT * FROM clubs WHERE name LIKE ? OR city LIKE ? ORDER BY created_at DESC",
            (like, like),
        ).fetchall()
    else:
        rows = con.execute("SELECT * FROM clubs ORDER BY created_at DESC").fetchall()
    result = [club_summary_json(con, r) for r in rows]
    con.close()
    result.sort(key=lambda c: c["totalPoints"], reverse=True)
    return result


@app.post("/v1/clubs")
def create_club(body: ClubCreateIn, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    if not body.name.strip():
        raise HTTPException(400, "Название клуба обязательно")
    con = connect()
    if current_club_id(con, uid):
        con.close()
        raise HTTPException(409, "Вы уже состоите в клубе")
    policy = body.joinPolicy if body.joinPolicy in ("open", "request") else "open"
    cid = f"c_{secrets.token_hex(8)}"
    con.execute(
        "INSERT INTO clubs (id,name,logo,city,description,owner_id,join_policy,created_at)"
        " VALUES (?,?,?,?,?,?,?,?)",
        (cid, body.name.strip(), body.logo, (body.city or "").strip() or None,
         (body.description or "").strip() or None, uid, policy, now_iso()),
    )
    con.execute(
        "INSERT INTO club_members (club_id,user_id,role,joined_at) VALUES (?,?,?,?)",
        (cid, uid, "owner", now_iso()),
    )
    con.commit()
    row = con.execute("SELECT * FROM clubs WHERE id=?", (cid,)).fetchone()
    result = club_detail_json(con, row, uid)
    con.close()
    return result


@app.get("/v1/clubs/me")
def my_club(authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    cid = current_club_id(con, uid)
    if not cid:
        con.close()
        return {"club": None}
    row = con.execute("SELECT * FROM clubs WHERE id=?", (cid,)).fetchone()
    result = club_detail_json(con, row, uid)
    con.close()
    return {"club": result}


@app.post("/v1/clubs/requests/{req_id}/approve")
def approve_request(req_id: str, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    req = con.execute("SELECT * FROM club_join_requests WHERE id=?", (req_id,)).fetchone()
    if not req or req["status"] != "pending":
        con.close()
        raise HTTPException(404, "Заявка не найдена")
    club = con.execute("SELECT * FROM clubs WHERE id=?", (req["club_id"],)).fetchone()
    if not club or club["owner_id"] != uid:
        con.close()
        raise HTTPException(403, "Только владелец клуба")
    if current_club_id(con, req["user_id"]):
        con.execute("UPDATE club_join_requests SET status='rejected' WHERE id=?", (req_id,))
        con.commit()
        con.close()
        raise HTTPException(409, "Пользователь уже состоит в клубе")
    con.execute(
        "INSERT INTO club_members (club_id,user_id,role,joined_at) VALUES (?,?,?,?)",
        (req["club_id"], req["user_id"], "member", now_iso()),
    )
    con.execute("UPDATE club_join_requests SET status='approved' WHERE id=?", (req_id,))
    con.commit()
    con.close()
    return {"status": "approved"}


@app.post("/v1/clubs/requests/{req_id}/reject")
def reject_request(req_id: str, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    req = con.execute("SELECT * FROM club_join_requests WHERE id=?", (req_id,)).fetchone()
    if not req:
        con.close()
        raise HTTPException(404, "Заявка не найдена")
    club = con.execute("SELECT * FROM clubs WHERE id=?", (req["club_id"],)).fetchone()
    if not club or club["owner_id"] != uid:
        con.close()
        raise HTTPException(403, "Только владелец клуба")
    con.execute("UPDATE club_join_requests SET status='rejected' WHERE id=?", (req_id,))
    con.commit()
    con.close()
    return {"status": "rejected"}


@app.get("/v1/clubs/{club_id}")
def club_detail(club_id: str, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    row = con.execute("SELECT * FROM clubs WHERE id=?", (club_id,)).fetchone()
    if not row:
        con.close()
        raise HTTPException(404, "Клуб не найден")
    result = club_detail_json(con, row, uid)
    con.close()
    return result


@app.patch("/v1/clubs/{club_id}")
def update_club(club_id: str, body: ClubUpdateIn, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    row = con.execute("SELECT * FROM clubs WHERE id=?", (club_id,)).fetchone()
    if not row:
        con.close()
        raise HTTPException(404, "Клуб не найден")
    if row["owner_id"] != uid:
        con.close()
        raise HTTPException(403, "Только владелец клуба")
    updates, values = [], []
    if body.name is not None and body.name.strip():
        updates.append("name=?"); values.append(body.name.strip())
    if body.logo is not None:
        updates.append("logo=?"); values.append(body.logo)
    if body.city is not None:
        updates.append("city=?"); values.append(body.city.strip() or None)
    if body.description is not None:
        updates.append("description=?"); values.append(body.description.strip() or None)
    if body.joinPolicy is not None and body.joinPolicy in ("open", "request"):
        updates.append("join_policy=?"); values.append(body.joinPolicy)
    if updates:
        con.execute(f"UPDATE clubs SET {', '.join(updates)} WHERE id=?", (*values, club_id))
        con.commit()
    row = con.execute("SELECT * FROM clubs WHERE id=?", (club_id,)).fetchone()
    result = club_detail_json(con, row, uid)
    con.close()
    return result


@app.post("/v1/clubs/{club_id}/join")
def join_club(club_id: str, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    club = con.execute("SELECT * FROM clubs WHERE id=?", (club_id,)).fetchone()
    if not club:
        con.close()
        raise HTTPException(404, "Клуб не найден")
    if current_club_id(con, uid):
        con.close()
        raise HTTPException(409, "Вы уже состоите в клубе")
    if club["join_policy"] == "open":
        con.execute(
            "INSERT INTO club_members (club_id,user_id,role,joined_at) VALUES (?,?,?,?)",
            (club_id, uid, "member", now_iso()),
        )
        con.commit()
        con.close()
        return {"status": "joined"}
    # join_policy == 'request'
    ex = con.execute(
        "SELECT 1 FROM club_join_requests WHERE club_id=? AND user_id=? AND status='pending'",
        (club_id, uid),
    ).fetchone()
    if not ex:
        con.execute(
            "INSERT INTO club_join_requests (id,club_id,user_id,status,created_at)"
            " VALUES (?,?,?,?,?)",
            (f"r_{secrets.token_hex(8)}", club_id, uid, "pending", now_iso()),
        )
        con.commit()
    con.close()
    return {"status": "requested"}


@app.post("/v1/clubs/{club_id}/leave")
def leave_club(club_id: str, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    m = con.execute(
        "SELECT * FROM club_members WHERE club_id=? AND user_id=?", (club_id, uid)
    ).fetchone()
    if not m:
        con.close()
        raise HTTPException(404, "Вы не состоите в этом клубе")
    if m["role"] == "owner":
        cnt = con.execute(
            "SELECT COUNT(*) c FROM club_members WHERE club_id=?", (club_id,)
        ).fetchone()["c"]
        if cnt > 1:
            con.close()
            raise HTTPException(409, "Владелец не может выйти, пока есть участники")
        con.execute("DELETE FROM club_members WHERE club_id=?", (club_id,))
        con.execute("DELETE FROM club_join_requests WHERE club_id=?", (club_id,))
        con.execute("DELETE FROM clubs WHERE id=?", (club_id,))
        con.commit()
        con.close()
        return {"status": "left", "clubDeleted": True}
    con.execute("DELETE FROM club_members WHERE club_id=? AND user_id=?", (club_id, uid))
    con.commit()
    con.close()
    return {"status": "left"}


@app.get("/v1/clubs/{club_id}/requests")
def club_requests(club_id: str, authorization: str | None = Header(default=None)):
    uid = user_id_from_token(authorization)
    con = connect()
    club = con.execute("SELECT * FROM clubs WHERE id=?", (club_id,)).fetchone()
    if not club:
        con.close()
        raise HTTPException(404, "Клуб не найден")
    if club["owner_id"] != uid:
        con.close()
        raise HTTPException(403, "Только владелец клуба")
    rows = con.execute(
        "SELECT r.id, r.user_id, u.name FROM club_join_requests r "
        "JOIN users u ON u.id=r.user_id "
        "WHERE r.club_id=? AND r.status='pending' ORDER BY r.created_at",
        (club_id,),
    ).fetchall()
    con.close()
    return [{"id": r["id"], "userId": r["user_id"], "name": r["name"]} for r in rows]


# ─── Рейтинг (по км из записей о беге) ─────────────────────────────────────────
# Метрика — пробежанные км: км = сумма начислений за бег (source='runnerRun') / 10.
# Берём именно ЗАРАБОТАННЫЕ за бег записи (не баланс кошелька) — значение не падает
# при тратах баллов в магазине. У каждой записи есть дата → режем по периодам.
def _period_start_iso(period: str) -> str:
    now = datetime.now(timezone.utc)
    if period == "week":
        start = (now - timedelta(days=now.weekday())).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
    elif period == "month":
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    else:  # all-time
        start = datetime(1970, 1, 1, tzinfo=timezone.utc)
    return start.isoformat()


def _club_name_for_user(con, uid):
    r = con.execute(
        "SELECT c.name FROM club_members m JOIN clubs c ON c.id=m.club_id "
        "WHERE m.user_id=?",
        (uid,),
    ).fetchone()
    return r["name"] if r else None


@app.get("/v1/leaderboard/users")
def leaderboard_users(
    period: str = "week",
    limit: int = 50,
    authorization: str | None = Header(default=None),
):
    me = user_id_from_token(authorization)
    if period not in ("week", "month", "all"):
        period = "week"
    start = _period_start_iso(period)
    con = connect()
    rows = con.execute(
        "SELECT u.id, u.name, COALESCE(SUM(t.amount),0) AS pts FROM users u "
        "LEFT JOIN loyalty_transactions t ON t.user_id=u.id "
        "AND t.source='runnerRun' AND t.created_at >= ? "
        "GROUP BY u.id, u.name",
        (start,),
    ).fetchall()
    ranked = sorted(
        ((r["id"], r["name"], r["pts"] / 10.0) for r in rows if r["pts"] > 0),
        key=lambda x: x[2],
        reverse=True,
    )
    top = [
        {
            "userId": uid,
            "name": name,
            "km": round(km, 1),
            "club": _club_name_for_user(con, uid),
            "rank": i + 1,
            "isMe": uid == me,
        }
        for i, (uid, name, km) in enumerate(ranked[:limit])
    ]
    my_rank = next((i + 1 for i, (uid, _, _) in enumerate(ranked) if uid == me), None)
    my_km = next((km for (uid, _, km) in ranked if uid == me), 0.0)
    con.close()
    return {
        "period": period,
        "top": top,
        "me": {"rank": my_rank, "km": round(my_km, 1)},
    }


@app.get("/v1/leaderboard/clubs")
def leaderboard_clubs(
    period: str = "week",
    limit: int = 50,
    authorization: str | None = Header(default=None),
):
    me = user_id_from_token(authorization)
    if period not in ("week", "month", "all"):
        period = "week"
    start = _period_start_iso(period)
    con = connect()
    my_club = current_club_id(con, me)
    rows = con.execute(
        "SELECT c.id, c.name, c.logo, COUNT(DISTINCT m.user_id) AS members, "
        "COALESCE(SUM(CASE WHEN t.source='runnerRun' AND t.created_at >= ? "
        "THEN t.amount ELSE 0 END),0) AS pts "
        "FROM clubs c JOIN club_members m ON m.club_id=c.id "
        "LEFT JOIN loyalty_transactions t ON t.user_id=m.user_id "
        "GROUP BY c.id, c.name, c.logo",
        (start,),
    ).fetchall()
    ranked = sorted(
        (
            {"id": r["id"], "name": r["name"], "logo": r["logo"],
             "members": r["members"], "km": round(r["pts"] / 10.0, 1)}
            for r in rows
        ),
        key=lambda x: x["km"],
        reverse=True,
    )
    top = []
    for i, c in enumerate(ranked[:limit]):
        c = {**c, "rank": i + 1, "isMine": c["id"] == my_club}
        top.append(c)
    my_rank = next((i + 1 for i, c in enumerate(ranked) if c["id"] == my_club), None)
    con.close()
    return {"period": period, "top": top, "myRank": my_rank}
