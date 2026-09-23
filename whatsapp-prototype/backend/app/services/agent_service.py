"""
Agent Service
Manages the agent request queue and intervention lifecycle.
"""

import uuid
from typing import Dict, List, Optional

from app.services.database import Database

db = Database()


async def get_agent_requests(organization_id: str) -> List[Dict]:
    """Return all conversations currently in WAITING_FOR_AGENT state."""
    convs = await db.get_org_conversations(organization_id)
    return [c for c in convs if c["state"] == "WAITING_FOR_AGENT"]


async def get_active_conversations(organization_id: str) -> List[Dict]:
    """Return conversations where an agent is actively involved."""
    convs = await db.get_org_conversations(organization_id)
    return [c for c in convs if c["state"] == "INTERVENED"]


async def get_attended_conversations(organization_id: str) -> List[Dict]:
    """Return conversations that have been attended and closed."""
    convs = await db.get_org_conversations(organization_id)
    return [c for c in convs if c["state"] == "ATTENDED"]


async def get_all_conversations(organization_id: str) -> List[Dict]:
    """Return all conversations for the organization with last-message preview."""
    convs = await db.get_org_conversations(organization_id)
    result = []
    for c in convs:
        last = await db.get_last_message(c["id"])
        c["last_message"] = last["text"] if last else ""
        c["last_message_time"] = last["created_at"] if last else c["created_at"]
        result.append(c)
    return result


async def intervene(conversation_id: str, agent_id: str = "agent_001") -> Dict:
    """
    Mark a conversation as INTERVENED.
    The bot will stop responding; the agent types directly.
    """
    conv = await db.get_conversation(conversation_id)
    if not conv:
        return {"success": False, "error": "Conversation not found"}

    await db.update_conversation_state(conversation_id, state="INTERVENED")

    # Post a system message so the user sees the agent joined
    await db.save_message({
        "id": str(uuid.uuid4()),
        "conversation_id": conversation_id,
        "sender_id": agent_id,
        "sender_type": "AGENT",
        "text": "✅ A team member has joined this conversation and will assist you shortly.",
        "message_type": "SYSTEM",
        "metadata": {"is_system": True},
        "status": "DELIVERED",
    })

    return {"success": True, "new_state": "INTERVENED"}


async def agent_leave(conversation_id: str, agent_id: str = "agent_001") -> Dict:
    """
    Mark a conversation as ATTENDED and re-enable the bot.
    """
    conv = await db.get_conversation(conversation_id)
    if not conv:
        return {"success": False, "error": "Conversation not found"}

    await db.update_conversation_state(
        conversation_id,
        state="ATTENDED",
        chatbot_state="MAIN_MENU",
    )

    await db.save_message({
        "id": str(uuid.uuid4()),
        "conversation_id": conversation_id,
        "sender_id": agent_id,
        "sender_type": "AGENT",
        "text": (
            "The team member has left this conversation. "
            "If you need further help, feel free to message again. "
            "The assistant is back online."
        ),
        "message_type": "SYSTEM",
        "metadata": {"is_system": True},
        "status": "DELIVERED",
    })

    return {"success": True, "new_state": "ATTENDED"}


async def agent_send_message(
    conversation_id: str,
    text: str,
    agent_id: str = "agent_001",
) -> Dict:
    """Allow a human agent to send a message inside an INTERVENED conversation."""
    conv = await db.get_conversation(conversation_id)
    if not conv:
        return {"success": False, "error": "Conversation not found"}
    if conv["state"] not in ("INTERVENED",):
        return {"success": False, "error": "Conversation is not in INTERVENED state"}

    msg = await db.save_message({
        "id": str(uuid.uuid4()),
        "conversation_id": conversation_id,
        "sender_id": agent_id,
        "sender_type": "AGENT",
        "text": text,
        "message_type": "TEXT",
        "metadata": {},
        "status": "DELIVERED",
    })
    return {"success": True, "message": msg}


async def get_request_count(organization_id: str) -> int:
    """Return number of conversations awaiting an agent."""
    requests = await get_agent_requests(organization_id)
    return len(requests)
