"""
School Chatbot Workflow — Phase 2 Institution Layer

This is the ONLY file that contains school-specific logic.
To deploy for a different institution:
  1. Replace this file with a new workflow
  2. Update the data in database.py seed section
  3. No Flutter code changes required

The workflow is injected into ChatbotEngine via dependency injection.
"""

from __future__ import annotations
import re
from typing import Dict, List, Optional

from app.services.chatbot_engine import BaseWorkflow, ChatbotResponse, ChatOption
from app.services.database import Database

db = Database()

# ── Agent escalation triggers (configurable per institution) ───────────────
AGENT_TRIGGERS = [
    "agent", "human", "person", "representative", "staff",
    "talk to someone", "speak to someone", "real person",
    "school office", "principal", "teacher", "complaint",
    "urgent", "emergency", "help me", "connect me",
    "someone please", "need help",
]

# ── Intent keywords ────────────────────────────────────────────────────────
INTENT_MAP = {
    "attendance":    ["attendance", "present", "absent", "missed", "bunked"],
    "homework":      ["homework", "assignment", "classwork", "hw", "task", "work"],
    "exam":          ["exam", "examination", "test", "schedule", "timetable", "when is"],
    "results":       ["result", "marks", "score", "grade", "performance", "report"],
    "fees":          ["fee", "fees", "payment", "pending", "balance", "paid", "due"],
    "transport":     ["transport", "bus", "route", "pickup", "drop"],
    "child_info":    ["child", "student", "information", "info", "details", "profile"],
    "school_info":   ["school", "timing", "hours", "contact", "address", "location",
                      "phone", "email", "website"],
    "menu":          ["menu", "help", "start", "hi", "hello", "hey", "namaste",
                      "good morning", "good afternoon", "back", "main"],
}


def _detect_intent(text: str) -> Optional[str]:
    t = text.lower().strip()
    for intent, keywords in INTENT_MAP.items():
        if any(k in t for k in keywords):
            return intent
    return None


def _fmt_currency(amount: float) -> str:
    return f"₹{int(amount):,}"


def _fmt_date(iso: str) -> str:
    """2026-10-10 → 10 Oct 2026"""
    try:
        from datetime import datetime
        return datetime.strptime(iso[:10], "%Y-%m-%d").strftime("%-d %b %Y")
    except Exception:
        return iso[:10]


class SchoolWorkflow(BaseWorkflow):
    """
    School-specific chatbot workflow for Sunrise International School.
    All school terminology, menus, and data lookups live here.
    """

    AGENT_TRIGGERS = AGENT_TRIGGERS

    def detect_agent_request(self, text: str) -> bool:
        t = text.lower()
        return any(trigger in t for trigger in self.AGENT_TRIGGERS)

    # ── Entry point ────────────────────────────────────────────────────────

    async def handle_async(
        self,
        state: str,
        text: str,
        data: Dict,
        org_config: Optional[Dict] = None,
    ) -> ChatbotResponse:
        """Async version — called by the engine adapter below."""

        org_id = (org_config or {}).get("id", "org_001")
        school_name = (org_config or {}).get("name", "our school")

        # ── Agent escalation (any state) ───────────────────────────────────
        if self.detect_agent_request(text):
            return ChatbotResponse(
                message=(
                    f"I can connect you with a school representative at "
                    f"{school_name}.\n\n"
                    "Please wait while your request is forwarded to our school team. "
                    "A staff member will join this conversation shortly. 🙏"
                ),
                next_state="WAITING_FOR_AGENT",
                agent_required=True,
            )

        # ── Global navigation shortcuts ────────────────────────────────────
        t_lower = text.strip().lower()
        if t_lower in ("menu", "main menu", "back", "start over", "restart",
                       "hi", "hello", "hey", "namaste"):
            if state not in ("START", ""):
                return await self._main_menu(school_name, data)

        if state in ("WAITING_FOR_AGENT",):
            return self._still_waiting()

        if state in ("INTERVENED", "ATTENDED"):
            return ChatbotResponse(message="", next_state=state, is_system=True)

        # ── State machine ──────────────────────────────────────────────────

        if state in ("START", ""):
            return await self._greet(school_name, org_id, data)

        # From GREETED/MAIN_MENU: check for specific intent first before showing menu
        if state in ("GREETED", "MAIN_MENU"):
            intent = _detect_intent(text)
            if intent and intent != "menu":
                return await self._dispatch_intent(intent, data, org_id, school_name)
            return await self._main_menu(school_name, data)

        if _detect_intent(text) == "menu":
            return await self._main_menu(school_name, data)

        # After main menu — handle option selection
        if state == "AWAITING_MENU_CHOICE":
            return await self._handle_menu_choice(text, data, org_id, school_name)

        # Child selection states
        if state == "SELECT_CHILD_ATTENDANCE":
            return await self._handle_child_select(text, data, "ATTENDANCE", org_id)
        if state == "SELECT_CHILD_HOMEWORK":
            return await self._handle_child_select(text, data, "HOMEWORK", org_id)
        if state == "SELECT_CHILD_EXAM":
            return await self._handle_child_select(text, data, "EXAM_SCHEDULE", org_id)
        if state == "SELECT_CHILD_RESULTS":
            return await self._handle_child_select(text, data, "RESULTS", org_id)
        if state == "SELECT_CHILD_FEES":
            return await self._handle_child_select(text, data, "FEES", org_id)
        if state == "SELECT_CHILD_TRANSPORT":
            return await self._handle_child_select(text, data, "TRANSPORT", org_id)
        if state == "SELECT_CHILD_INFO":
            return await self._handle_child_select(text, data, "CHILD_INFO", org_id)

        # Leaf states (showing info) — any message returns to menu
        if state in ("ATTENDANCE","HOMEWORK","EXAM_SCHEDULE","RESULTS",
                     "FEES","TRANSPORT","CHILD_INFO","SCHOOL_INFO"):
            # Allow follow-up intents from these states
            intent = _detect_intent(text)
            if intent and intent != "menu":
                return await self._dispatch_intent(intent, data, org_id, school_name)
            return await self._main_menu(school_name, data)

        # Intent-based routing from anywhere
        intent = _detect_intent(text)
        if intent:
            return await self._dispatch_intent(intent, data, org_id, school_name)

        # Fallback
        return self._fallback(school_name)

    # Sync shim — the base engine expects a sync handle(); we override with async
    def handle(self, state, text, data, org_config=None):
        raise RuntimeError("Use handle_async()")

    # ── Greet ──────────────────────────────────────────────────────────────

    async def _greet(self, school_name: str, org_id: str, data: Dict) -> ChatbotResponse:
        config = await db.get_school_config(org_id)
        year = config["academic_year"] if config else "2026-27"
        return ChatbotResponse(
            message=(
                f"🏫 *Welcome to {school_name}*\n\n"
                f"I am the school's virtual assistant for the academic year *{year}*.\n\n"
                "I can assist you with:\n"
                "• Student information & attendance\n"
                "• Homework & assignments\n"
                "• Examination schedules & results\n"
                "• Fee status & transport\n"
                "• General school information\n\n"
                "How may I assist you today?"
            ),
            options=[ChatOption("menu", "📋 View Services")],
            next_state="GREETED",
        )

    # ── Main menu ──────────────────────────────────────────────────────────

    async def _main_menu(self, school_name: str, data: Dict) -> ChatbotResponse:
        return ChatbotResponse(
            message=f"*{school_name}* — How may I assist you?",
            options=[
                ChatOption("child_info",  "👤 Child Information"),
                ChatOption("attendance",  "📅 Attendance"),
                ChatOption("homework",    "📚 Homework"),
                ChatOption("results",     "📊 Exam Results"),
                ChatOption("exam",        "🗓️  Exam Schedule"),
                ChatOption("fees",        "💳 Fee Information"),
                ChatOption("transport",   "🚌 Transport"),
                ChatOption("school_info", "🏫 School Information"),
                ChatOption("agent",       "👨‍💼 Talk to a Representative"),
            ],
            next_state="AWAITING_MENU_CHOICE",
        )

    # ── Menu choice dispatcher ─────────────────────────────────────────────

    async def _handle_menu_choice(
        self, text: str, data: Dict, org_id: str, school_name: str
    ) -> ChatbotResponse:
        opt = re.sub(r"[^a-z0-9_]", "", text.strip().lower())
        intent = _detect_intent(text) or opt

        if intent in ("child_info", "childinfo", "child", "information", "info", "details"):
            return await self._ask_child(data, org_id, "SELECT_CHILD_INFO")
        if intent in ("attendance", "present", "absent"):
            return await self._ask_child(data, org_id, "SELECT_CHILD_ATTENDANCE")
        if intent in ("homework", "assignment", "hw"):
            return await self._ask_child(data, org_id, "SELECT_CHILD_HOMEWORK")
        if intent in ("results", "marks", "score", "grade"):
            return await self._ask_child(data, org_id, "SELECT_CHILD_RESULTS")
        if intent in ("exam", "schedule", "timetable", "examination"):
            return await self._ask_child(data, org_id, "SELECT_CHILD_EXAM")
        if intent in ("fees", "fee", "payment"):
            return await self._ask_child(data, org_id, "SELECT_CHILD_FEES")
        if intent in ("transport", "bus", "route"):
            return await self._ask_child(data, org_id, "SELECT_CHILD_TRANSPORT")
        if intent in ("school_info", "school", "info", "timing", "contact", "address"):
            return await self._school_info(org_id, school_name)
        if intent in ("agent", "representative", "human"):
            return ChatbotResponse(
                message=(
                    f"I can connect you with a school representative at {school_name}. "
                    "Please wait while your request is forwarded to our school team. 🙏"
                ),
                next_state="WAITING_FOR_AGENT",
                agent_required=True,
            )
        return self._fallback(school_name)

    async def _dispatch_intent(
        self, intent: str, data: Dict, org_id: str, school_name: str
    ) -> ChatbotResponse:
        if intent == "child_info":
            return await self._ask_child(data, org_id, "SELECT_CHILD_INFO")
        if intent == "attendance":
            return await self._ask_child(data, org_id, "SELECT_CHILD_ATTENDANCE")
        if intent == "homework":
            return await self._ask_child(data, org_id, "SELECT_CHILD_HOMEWORK")
        if intent in ("results", "exam"):
            return await self._ask_child(data, org_id, "SELECT_CHILD_RESULTS")
        if intent == "fees":
            return await self._ask_child(data, org_id, "SELECT_CHILD_FEES")
        if intent == "transport":
            return await self._ask_child(data, org_id, "SELECT_CHILD_TRANSPORT")
        if intent == "school_info":
            return await self._school_info(org_id, school_name)
        return self._fallback(school_name)

    # ── Child selection ────────────────────────────────────────────────────

    async def _ask_child(
        self, data: Dict, org_id: str, next_state: str
    ) -> ChatbotResponse:
        user_id = data.get("user_id", "")
        if not user_id:
            return ChatbotResponse(
                message="I'm unable to identify your account. Please contact the school office.",
                next_state="MAIN_MENU",
            )
        students = await db.get_students_for_user(user_id, org_id)
        if not students:
            return ChatbotResponse(
                message=(
                    "I could not find any students linked to your account in our records.\n\n"
                    "Please contact the school office for assistance."
                ),
                options=[ChatOption("menu", "🏠 Main Menu")],
                next_state="MAIN_MENU",
            )
        if len(students) == 1:
            # Auto-select the only child
            data["selected_student"] = students[0]["id"]
            return await self._fetch_and_respond(next_state, data, students[0])

        # Store list for selection
        data["pending_action"] = next_state
        data["student_list"] = [{"id": s["id"], "name": s["name"]} for s in students]

        return ChatbotResponse(
            message="Please select the child whose information you would like to view:",
            options=[ChatOption(s["id"], s["name"]) for s in students],
            next_state=next_state,
        )

    async def _handle_child_select(
        self, text: str, data: Dict, action: str, org_id: str
    ) -> ChatbotResponse:
        student_list = data.get("student_list", [])
        text_lower = text.strip().lower()

        # Match by option id (student id) or name
        selected_id = None
        for s in student_list:
            if text.strip() == s["id"] or text_lower in s["name"].lower():
                selected_id = s["id"]
                break

        # Direct match by student id
        if not selected_id and text.strip().startswith("stu_"):
            selected_id = text.strip()

        if not selected_id:
            names = [s["name"] for s in student_list]
            return ChatbotResponse(
                message=(
                    f"I'm sorry, I didn't recognise that selection.\n\n"
                    f"Please choose from: {', '.join(names)}"
                ),
                options=[ChatOption(s["id"], s["name"]) for s in student_list],
                next_state=action,
            )

        data["selected_student"] = selected_id
        student = await db.get_student_by_id(selected_id)
        if not student:
            return self._fallback("school")
        return await self._fetch_and_respond(action, data, student)

    # ── Data fetch & response builders ────────────────────────────────────

    async def _fetch_and_respond(
        self, action: str, data: Dict, student: Dict
    ) -> ChatbotResponse:
        sid = student["id"]
        name = student["name"]
        class_name = student["class_name"]
        stream = student.get("stream", "")
        class_display = f"{class_name} ({stream})" if stream else class_name
        section = student["section_name"]

        if action == "CHILD_INFO":
            return self._respond_child_info(student, class_display, section)

        if action == "ATTENDANCE":
            records = await db.get_attendance(sid)
            return self._respond_attendance(name, records)

        if action == "HOMEWORK":
            hw = await db.get_homework(student["class_id"], student["section_id"])
            return self._respond_homework(name, class_display, section, hw)

        if action == "EXAM_SCHEDULE":
            schedule = await db.get_exam_schedule(student["class_id"])
            return self._respond_exam_schedule(name, class_display, schedule)

        if action == "RESULTS":
            marks = await db.get_marks(sid)
            return self._respond_results(name, class_display, marks)

        if action == "FEES":
            fee = await db.get_fees(sid)
            return self._respond_fees(name, fee)

        if action == "TRANSPORT":
            trn = await db.get_transport(sid)
            return self._respond_transport(name, trn)

        return self._fallback("school")

    # ── Response formatters ────────────────────────────────────────────────

    def _respond_child_info(self, s: Dict, class_display: str, section: str) -> ChatbotResponse:
        dob = _fmt_date(s.get("date_of_birth","")) if s.get("date_of_birth") else "—"
        return ChatbotResponse(
            message=(
                f"*Student Information*\n\n"
                f"Name: {s['name']}\n"
                f"Student ID: {s['student_code']}\n"
                f"Date of Birth: {dob}\n"
                f"Gender: {s.get('gender','—')}\n"
                f"Class: {class_display}\n"
                f"Section: {section}\n"
                f"Roll No.: {s.get('roll_no','—')}\n"
                f"Class Teacher: {s.get('teacher_name','—')}"
            ),
            options=[
                ChatOption("attendance", "📅 Attendance"),
                ChatOption("menu",       "🏠 Main Menu"),
            ],
            next_state="CHILD_INFO",
        )

    def _respond_attendance(self, name: str, records: List[Dict]) -> ChatbotResponse:
        if not records:
            return ChatbotResponse(
                message=f"According to our school records, attendance data for *{name}* is not yet available for this period.",
                options=[ChatOption("menu","🏠 Main Menu")],
                next_state="ATTENDANCE",
            )
        total   = len(records)
        present = sum(1 for r in records if r["status"] == "Present")
        absent  = total - present
        pct     = round(present / total * 100, 1) if total else 0
        absents = sorted(
            [r["date"] for r in records if r["status"] == "Absent"], reverse=True
        )[:5]
        absent_str = "\n".join(f"• {_fmt_date(d)}" for d in absents) if absents else "None"

        return ChatbotResponse(
            message=(
                f"*Attendance Summary — {name}*\n\n"
                f"Present: {present} day{'s' if present!=1 else ''}\n"
                f"Absent:  {absent} day{'s' if absent!=1 else ''}\n"
                f"Attendance: *{pct}%*\n\n"
                f"Recent absences:\n{absent_str}"
            ),
            options=[
                ChatOption("homework", "📚 Homework"),
                ChatOption("menu",     "🏠 Main Menu"),
            ],
            next_state="ATTENDANCE",
        )

    def _respond_homework(
        self, name: str, class_display: str, section: str, hw: List[Dict]
    ) -> ChatbotResponse:
        if not hw:
            return ChatbotResponse(
                message=(
                    f"According to our school records, no homework has been assigned "
                    f"for *{class_display} — Section {section}* at this time."
                ),
                options=[ChatOption("menu","🏠 Main Menu")],
                next_state="HOMEWORK",
            )
        lines = [f"*Homework — {class_display}, Sec {section}*\n"]
        for h in hw[:6]:
            lines.append(f"📖 *{h['subject']}*\n{h['description']}\nDue: {_fmt_date(h['due_date'])}\n")
        return ChatbotResponse(
            message="\n".join(lines).strip(),
            options=[
                ChatOption("exam", "🗓️  Exam Schedule"),
                ChatOption("menu", "🏠 Main Menu"),
            ],
            next_state="HOMEWORK",
        )

    def _respond_exam_schedule(
        self, name: str, class_display: str, schedule: List[Dict]
    ) -> ChatbotResponse:
        if not schedule:
            return ChatbotResponse(
                message=(
                    f"The examination schedule for *{class_display}* has not been "
                    f"published yet. Please check back later."
                ),
                options=[ChatOption("menu","🏠 Main Menu")],
                next_state="EXAM_SCHEDULE",
            )
        exam_name = schedule[0].get("exam_name","Examination")
        lines = [f"*{exam_name} — {class_display}*\n"]
        for s in schedule[:8]:
            lines.append(
                f"📝 *{s['subject']}*\n"
                f"   Date: {_fmt_date(s['exam_date'])}\n"
                f"   Time: {s['start_time']} – {s['end_time']}\n"
                f"   Room: {s.get('room_no','TBA')}\n"
            )
        return ChatbotResponse(
            message="\n".join(lines).strip(),
            options=[
                ChatOption("results", "📊 Results"),
                ChatOption("menu",    "🏠 Main Menu"),
            ],
            next_state="EXAM_SCHEDULE",
        )

    def _respond_results(self, name: str, class_display: str, marks: List[Dict]) -> ChatbotResponse:
        if not marks:
            return ChatbotResponse(
                message=(
                    f"According to our school records, examination results for "
                    f"*{name}* are not yet available."
                ),
                options=[
                    ChatOption("exam",  "🗓️  Exam Schedule"),
                    ChatOption("menu",  "🏠 Main Menu"),
                ],
                next_state="RESULTS",
            )
        exam_name = marks[0].get("exam_name","Unit Test")
        total_obt = sum(m["marks_obtained"] for m in marks)
        total_max = sum(m["max_marks"] for m in marks)
        overall   = round(total_obt / total_max * 100, 1) if total_max else 0
        lines = [f"*{exam_name} Results — {name}*\n"]
        for m in marks:
            pct = round(m["marks_obtained"] / m["max_marks"] * 100)
            lines.append(
                f"{m['subject']}: {int(m['marks_obtained'])}/{int(m['max_marks'])} ({pct}%)"
            )
        lines.append(f"\n*Overall: {overall}%*")
        return ChatbotResponse(
            message="\n".join(lines),
            options=[
                ChatOption("fees", "💳 Fee Status"),
                ChatOption("menu", "🏠 Main Menu"),
            ],
            next_state="RESULTS",
        )

    def _respond_fees(self, name: str, fee: Optional[Dict]) -> ChatbotResponse:
        if not fee:
            return ChatbotResponse(
                message=(
                    f"According to our school records, fee information for "
                    f"*{name}* is not available. Please contact the school office."
                ),
                options=[ChatOption("menu","🏠 Main Menu")],
                next_state="FEES",
            )
        status_emoji = {"Paid":"✅","Partial":"⚠️","Pending":"❌"}.get(fee["status"],"•")
        return ChatbotResponse(
            message=(
                f"*Fee Information — {name}*\n"
                f"Academic Year: {fee['academic_year']}\n\n"
                f"Total Fee:    {_fmt_currency(fee['total_fee'])}\n"
                f"Paid:         {_fmt_currency(fee['paid_amount'])}\n"
                f"Pending:      {_fmt_currency(fee['pending_amount'])}\n\n"
                f"Status: {status_emoji} *{fee['status']}*\n\n"
                "For fee payment, please visit the school office or use the school's payment portal."
            ),
            options=[
                ChatOption("transport", "🚌 Transport"),
                ChatOption("menu",      "🏠 Main Menu"),
            ],
            next_state="FEES",
        )

    def _respond_transport(self, name: str, trn: Optional[Dict]) -> ChatbotResponse:
        if not trn:
            return ChatbotResponse(
                message=(
                    f"According to our school records, *{name}* is not enrolled "
                    f"in the school transport service.\n\n"
                    "To enrol, please contact the school office."
                ),
                options=[ChatOption("menu","🏠 Main Menu")],
                next_state="TRANSPORT",
            )
        return ChatbotResponse(
            message=(
                f"*Transport Information — {name}*\n\n"
                f"Route:        {trn['route_no']}\n"
                f"Pickup Point: {trn['pickup_point']}\n"
                f"Transport Fee: {_fmt_currency(trn['transport_fee'])} / year\n"
                f"Status:       ✅ {trn['status']}"
            ),
            options=[
                ChatOption("fees", "💳 Fees"),
                ChatOption("menu", "🏠 Main Menu"),
            ],
            next_state="TRANSPORT",
        )

    async def _school_info(self, org_id: str, school_name: str) -> ChatbotResponse:
        config = await db.get_school_config(org_id)
        if not config:
            return ChatbotResponse(
                message=f"School information for *{school_name}* is not currently available.",
                options=[ChatOption("menu","🏠 Main Menu")],
                next_state="SCHOOL_INFO",
            )
        return ChatbotResponse(
            message=(
                f"🏫 *{config['school_name']}*\n\n"
                f"📍 Address:\n{config['address']}\n\n"
                f"📞 Phone: {config['phone']}\n"
                f"📧 Email: {config['email']}\n"
                f"🌐 Website: {config['website']}\n\n"
                f"🕐 Office Hours:\n{config['office_hours']}\n\n"
                f"📚 Classes: {config['classes_info']}\n"
                f"🗓️  Academic Year: {config['academic_year']}"
            ),
            options=[
                ChatOption("agent", "👨‍💼 Contact Representative"),
                ChatOption("menu",  "🏠 Main Menu"),
            ],
            next_state="SCHOOL_INFO",
        )

    def _still_waiting(self) -> ChatbotResponse:
        return ChatbotResponse(
            message=(
                "⏳ Your request has been forwarded to our school team. "
                "A representative will join this conversation shortly.\n\n"
                "Type *menu* if you'd like to cancel and return to the main menu."
            ),
            next_state="WAITING_FOR_AGENT",
        )

    def _fallback(self, school_name: str) -> ChatbotResponse:
        return ChatbotResponse(
            message=(
                "I'm sorry, I don't have enough information to answer that. 🙏\n\n"
                "You may choose one of the available school services, or I can "
                "connect you with a school representative."
            ),
            options=[
                ChatOption("menu",  "📋 Main Menu"),
                ChatOption("agent", "👨‍💼 Talk to Representative"),
            ],
            next_state="AWAITING_MENU_CHOICE",
        )
