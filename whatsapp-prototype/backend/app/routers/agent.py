"""
Agent Router — consumed by the Flutter Business Mode.
"""

from fastapi import APIRouter, HTTPException
from typing import List

from app.models.schemas import (
    AgentCountOut, ConversationOut, MessageOut,
    AgentMessageRequest, AgentActionRequest,
    BusinessProfileRequest,
)
from app.services import agent_service
from app.services.database import Database

router = APIRouter()
db = Database()


# ── Business Profile ──────────────────────────────────────────────────────

@router.post("/profile")
async def save_business_profile(req: BusinessProfileRequest):
    """Save or update the business profile for an organisation."""
    profile = await db.upsert_business_profile(req.model_dump())
    return {"success": True, "profile": profile}


@router.get("/profile/{org_id}")
async def get_business_profile(org_id: str):
    """Retrieve a saved business profile."""
    profile = await db.get_business_profile(org_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile


# ── Conversation Queues ───────────────────────────────────────────────────

@router.get("/conversations/{org_id}", response_model=List[ConversationOut])
async def get_all_conversations(org_id: str) -> List[ConversationOut]:
    """Return all conversations for the business chat list."""
    convs = await agent_service.get_all_conversations(org_id)
    return _to_conv_out_list(convs)


@router.get("/requests/{org_id}", response_model=List[ConversationOut])
async def get_agent_requests(org_id: str) -> List[ConversationOut]:
    """Return conversations in WAITING_FOR_AGENT state."""
    convs = await agent_service.get_agent_requests(org_id)
    enriched = []
    for c in convs:
        last = await db.get_last_message(c["id"])
        c["last_message"] = last["text"] if last else ""
        c["last_message_time"] = last["created_at"] if last else c["created_at"]
        enriched.append(c)
    return _to_conv_out_list(enriched)


@router.get("/requests/{org_id}/count", response_model=AgentCountOut)
async def get_request_count(org_id: str) -> AgentCountOut:
    """Return the number of pending agent requests (for the badge)."""
    count = await agent_service.get_request_count(org_id)
    return AgentCountOut(count=count, organization_id=org_id)


@router.get("/active/{org_id}", response_model=List[ConversationOut])
async def get_active_conversations(org_id: str) -> List[ConversationOut]:
    """Return conversations currently in INTERVENED state."""
    convs = await agent_service.get_active_conversations(org_id)
    return _to_conv_out_list(convs)


@router.get("/attended/{org_id}", response_model=List[ConversationOut])
async def get_attended_conversations(org_id: str) -> List[ConversationOut]:
    """Return conversations in ATTENDED state."""
    convs = await agent_service.get_attended_conversations(org_id)
    return _to_conv_out_list(convs)


# ── Conversation History ──────────────────────────────────────────────────

@router.get("/conversation/{conv_id}/messages", response_model=List[MessageOut])
async def get_conversation_messages(conv_id: str) -> List[MessageOut]:
    """Return all messages for a specific conversation (business side)."""
    messages = await db.get_conversation_messages(conv_id)
    return [MessageOut(**m) for m in messages]


# ── Agent Actions ─────────────────────────────────────────────────────────

@router.post("/conversations/{conv_id}/intervene")
async def intervene(conv_id: str, req: AgentActionRequest = AgentActionRequest()):
    """Take over a conversation (WAITING_FOR_AGENT → INTERVENED)."""
    result = await agent_service.intervene(conv_id, req.agent_id)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error"))
    return result


@router.post("/conversations/{conv_id}/leave")
async def leave_conversation(conv_id: str, req: AgentActionRequest = AgentActionRequest()):
    """Leave a conversation (INTERVENED → ATTENDED)."""
    result = await agent_service.agent_leave(conv_id, req.agent_id)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error"))
    return result


@router.post("/conversations/{conv_id}/message")
async def send_agent_message(conv_id: str, req: AgentMessageRequest):
    """Send a message as an agent inside an INTERVENED conversation."""
    result = await agent_service.agent_send_message(conv_id, req.text, req.agent_id)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error"))
    return result


# ── Helper ────────────────────────────────────────────────────────────────

def _to_conv_out_list(convs: list) -> List[ConversationOut]:
    result = []
    for c in convs:
        result.append(ConversationOut(
            id=c["id"],
            organization_id=c["organization_id"],
            user_id=c["user_id"],
            user_name=c.get("user_name", "Unknown"),
            user_phone=c.get("user_phone"),
            state=c["state"],
            chatbot_state=c.get("chatbot_state", "START"),
            last_message=c.get("last_message", ""),
            last_message_time=c.get("last_message_time", c.get("updated_at", "")),
            created_at=c["created_at"],
            updated_at=c["updated_at"],
        ))
    return result
