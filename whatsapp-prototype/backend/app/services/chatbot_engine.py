"""
Chatbot Engine — Platform Layer (Phase 2 updated)

The engine is institution-agnostic.
Institution logic is injected via a workflow object.
SchoolWorkflow is the default for Phase 2.
"""

from __future__ import annotations
import asyncio
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any


@dataclass
class ChatOption:
    id: str
    label: str

@dataclass
class ChatbotResponse:
    message: str
    options: List[ChatOption] = field(default_factory=list)
    next_state: str = "MAIN_MENU"
    agent_required: bool = False
    is_system: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return {
            "message": self.message,
            "options": [{"id": o.id, "label": o.label} for o in self.options],
            "next_state": self.next_state,
            "agent_required": self.agent_required,
            "is_system": self.is_system,
        }


class BaseWorkflow:
    """Platform contract — override to supply institution logic."""

    AGENT_TRIGGERS: List[str] = ["agent","human","person","representative"]

    def detect_agent_request(self, text: str) -> bool:
        t = text.lower()
        return any(tr in t for tr in self.AGENT_TRIGGERS)

    def handle(self, state, text, data, org_config=None) -> ChatbotResponse:
        raise NotImplementedError

    async def handle_async(self, state, text, data, org_config=None) -> ChatbotResponse:
        """Override in async workflows. Default delegates to sync handle()."""
        return self.handle(state, text, data, org_config)


class ChatbotEngine:
    """
    Stateless engine. All state comes in, processed response goes out.
    Supports both sync and async workflows.
    """

    def __init__(self, workflow: Optional[BaseWorkflow] = None):
        if workflow is None:
            # Lazy import to avoid circular imports at module level
            from app.services.school_workflow import SchoolWorkflow
            workflow = SchoolWorkflow()
        self.workflow = workflow

    async def process_async(
        self,
        current_state: str,
        user_text: str,
        session_data: Dict,
        org_config: Optional[Dict] = None,
    ) -> ChatbotResponse:
        if not user_text.strip():
            return ChatbotResponse(
                message="Please type a message and I'll be happy to help you.",
                next_state=current_state,
            )
        return await self.workflow.handle_async(
            state=current_state,
            text=user_text,
            data=session_data,
            org_config=org_config,
        )

    def process(self, current_state, user_text, session_data, org_config=None):
        """Sync shim for backward compat — runs the async version in a new loop if needed."""
        return asyncio.get_event_loop().run_until_complete(
            self.process_async(current_state, user_text, session_data, org_config)
        )
