"""
Request / Response schemas (Pydantic v2)
"""

from __future__ import annotations
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


# ── Incoming requests ─────────────────────────────────────────────────────

class ChatRequest(BaseModel):
    session_id: str = Field(..., description="User / device identifier")
    organization_id: str = Field(..., description="Target organisation ID")
    message: str = Field(..., description="User's text message")


class BusinessProfileRequest(BaseModel):
    organization_id: str
    name: str
    verified: bool = False
    description: str = ""
    category: str = "Education"
    avatar_color: str = "#075E54"


class AgentMessageRequest(BaseModel):
    text: str
    agent_id: str = "agent_001"


class AgentActionRequest(BaseModel):
    agent_id: str = "agent_001"


# ── Outgoing responses ────────────────────────────────────────────────────

class ChatOption(BaseModel):
    id: str
    label: str


class ChatResponse(BaseModel):
    conversation_id: Optional[str]
    message: Optional[str]
    options: List[ChatOption] = []
    conversation_state: str
    chatbot_state: str
    agent_required: bool = False
    bot_responded: bool = True
    error: bool = False


class OrganizationOut(BaseModel):
    id: str
    name: str
    category: str
    description: str
    verified: bool
    avatar_color: str


class ConversationOut(BaseModel):
    id: str
    organization_id: str
    user_id: str
    user_name: str
    user_phone: Optional[str]
    state: str
    chatbot_state: str
    last_message: str = ""
    last_message_time: str = ""
    created_at: str
    updated_at: str


class MessageOut(BaseModel):
    id: str
    conversation_id: str
    sender_id: str
    sender_type: str   # USER | BOT | AGENT
    text: str
    message_type: str  # TEXT | OPTION | SYSTEM
    metadata: Dict[str, Any] = {}
    status: str
    created_at: str


class AgentCountOut(BaseModel):
    count: int
    organization_id: str


class HealthOut(BaseModel):
    status: str
    database: str
    environment: str = "development"
