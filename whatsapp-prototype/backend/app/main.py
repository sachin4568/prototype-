"""
WhatsApp Chatbot Prototype — FastAPI Backend
Phase 1: Platform Foundation

Run with:
    uvicorn app.main:app --reload --port 8000

No Meta credentials, MongoDB, or cloud services required.
"""

import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.routers import chat, agent
from app.services.database import Database

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="WhatsApp Chatbot Prototype API",
    description=(
        "Local prototype backend for the WhatsApp-style organisational chatbot. "
        "No external credentials required."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Allow Flutter app running on any localhost port
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────
app.include_router(chat.router,  prefix="/api/chat",  tags=["Chat"])
app.include_router(agent.router, prefix="/api/agent", tags=["Agent / Business"])


# ── Lifecycle ─────────────────────────────────────────────────────────────

@app.on_event("startup")
async def startup():
    logger.info("Initialising prototype database…")
    db = Database()
    await db.initialise()
    logger.info("Prototype ready. Docs at http://localhost:8000/docs")


# ── Core endpoints ────────────────────────────────────────────────────────

@app.get("/", tags=["Root"])
async def root():
    return {
        "service": "WhatsApp Chatbot Prototype",
        "phase": 1,
        "docs": "http://localhost:8000/docs",
    }


@app.get("/health", tags=["Root"])
async def health():
    db = Database()
    ok = await db.ping()
    return JSONResponse(
        status_code=200 if ok else 503,
        content={
            "status": "healthy" if ok else "unhealthy",
            "database": "connected" if ok else "error",
            "environment": "development",
        }
    )
