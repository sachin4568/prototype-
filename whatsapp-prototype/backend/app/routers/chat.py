"""
Chat Router — primary API consumed by the Flutter user side.
"""

from fastapi import APIRouter, HTTPException
from typing import List

from app.models.schemas import (
    ChatRequest, ChatResponse, MessageOut, OrganizationOut
)
from app.services import conversation_service
from app.services.database import Database

router = APIRouter()
db = Database()


@router.post("", response_model=ChatResponse)
async def send_message(req: ChatRequest) -> ChatResponse:
    """
    Process a user message and return a chatbot response.
    This is the primary endpoint the Flutter app calls.
    """
    if not req.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    result = await conversation_service.handle_user_message(
        session_id=req.session_id,
        organization_id=req.organization_id,
        user_text=req.message,
    )

    return ChatResponse(
        conversation_id=result.get("conversation_id"),
        message=result.get("message"),
        options=[
            {"id": o["id"], "label": o["label"]}
            for o in result.get("options", [])
        ],
        conversation_state=result.get("conversation_state", "BOT_ACTIVE"),
        chatbot_state=result.get("chatbot_state", "START"),
        agent_required=result.get("agent_required", False),
        bot_responded=result.get("bot_responded", True),
        error=result.get("error", False),
    )


@router.get("/history/{conversation_id}", response_model=List[MessageOut])
async def get_history(conversation_id: str) -> List[MessageOut]:
    """Return full message history for a conversation."""
    messages = await conversation_service.get_conversation_history(conversation_id)
    return [MessageOut(**m) for m in messages]


@router.get("/organizations", response_model=List[OrganizationOut])
async def search_organizations(q: str = "") -> List[OrganizationOut]:
    """Search organisations by name (used by User Mode search screen)."""
    orgs = await db.get_organizations(q)
    return [
        OrganizationOut(
            id=o["id"],
            name=o["name"],
            category=o.get("category", "Organization"),
            description=o.get("description", ""),
            verified=bool(o.get("verified", 0)),
            avatar_color=o.get("avatar_color", "#075E54"),
        )
        for o in orgs
    ]


@router.get("/organizations/{org_id}", response_model=OrganizationOut)
async def get_organization(org_id: str) -> OrganizationOut:
    """Get a single organisation by ID."""
    org = await db.get_organization(org_id)
    if not org:
        raise HTTPException(status_code=404, detail="Organisation not found")
    return OrganizationOut(
        id=org["id"],
        name=org["name"],
        category=org.get("category", "Organization"),
        description=org.get("description", ""),
        verified=bool(org.get("verified", 0)),
        avatar_color=org.get("avatar_color", "#075E54"),
    )
