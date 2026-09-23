"""
Conversation Service — Phase 2
Coordinates DB ↔ ChatbotEngine ↔ AgentSystem.
Now uses async engine and injects user_id into session data for school queries.
"""

import json
import uuid
from typing import Dict, List

from app.services.database import Database
from app.services.chatbot_engine import ChatbotEngine

db = Database()
engine = ChatbotEngine()


async def handle_user_message(
    session_id: str,
    organization_id: str,
    user_text: str,
) -> Dict:
    org = await db.get_organization(organization_id)
    if not org:
        return _error("Organisation not found.")

    conv = await db.get_or_create_conversation(organization_id, session_id)
    conv_id = conv["id"]

    # Save user message
    await db.save_message({
        "id": str(uuid.uuid4()),
        "conversation_id": conv_id,
        "sender_id": session_id,
        "sender_type": "USER",
        "text": user_text,
        "message_type": "TEXT",
        "metadata": {},
        "status": "READ",
    })

    current_conv_state = conv["state"]
    chatbot_state = conv["chatbot_state"]
    chatbot_data = json.loads(conv.get("chatbot_data") or "{}")

    # Inject user_id so school workflow can fetch their students
    chatbot_data["user_id"] = session_id

    if current_conv_state == "INTERVENED":
        return {
            "conversation_id": conv_id,
            "message": None,
            "options": [],
            "conversation_state": current_conv_state,
            "chatbot_state": chatbot_state,
            "agent_required": False,
            "bot_responded": False,
        }

    # Run school chatbot
    bot_response = await engine.process_async(
        current_state=chatbot_state,
        user_text=user_text,
        session_data=chatbot_data,
        org_config=org,
    )

    new_conv_state = current_conv_state
    if bot_response.agent_required or bot_response.next_state == "WAITING_FOR_AGENT":
        new_conv_state = "WAITING_FOR_AGENT"

    await db.update_conversation_state(
        conv_id,
        state=new_conv_state,
        chatbot_state=bot_response.next_state,
        chatbot_data=chatbot_data,
    )

    if bot_response.message:
        meta = {}
        if bot_response.options:
            meta["options"] = [{"id": o.id, "label": o.label} for o in bot_response.options]
        await db.save_message({
            "id": str(uuid.uuid4()),
            "conversation_id": conv_id,
            "sender_id": "BOT",
            "sender_type": "BOT",
            "text": bot_response.message,
            "message_type": "OPTION" if bot_response.options else "TEXT",
            "metadata": meta,
            "status": "DELIVERED",
        })

    return {
        "conversation_id": conv_id,
        "message": bot_response.message,
        "options": [{"id": o.id, "label": o.label} for o in bot_response.options],
        "conversation_state": new_conv_state,
        "chatbot_state": bot_response.next_state,
        "agent_required": bot_response.agent_required,
        "bot_responded": True,
    }


async def get_conversation_history(conv_id: str) -> List[Dict]:
    return await db.get_conversation_messages(conv_id)


def _error(msg: str) -> Dict:
    return {
        "conversation_id": None,
        "message": msg,
        "options": [],
        "conversation_state": "BOT_ACTIVE",
        "chatbot_state": "START",
        "agent_required": False,
        "bot_responded": True,
        "error": True,
    }
