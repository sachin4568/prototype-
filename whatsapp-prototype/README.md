# WhatsApp Chatbot Prototype — School Edition
### Phase 1 & 2 Complete

A functional, locally-runnable WhatsApp-style organisational chatbot prototype demonstrating
a K-12 school communicating with parents through an automated assistant, with human-agent
intervention support.

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   FLUTTER APP                         │
│   Business Mode ◄──────────────────► User Mode       │
│   (School Staff)                    (Parent)          │
└─────────────────────────┬────────────────────────────┘
                          │ HTTP / JSON
                          ▼
┌──────────────────────────────────────────────────────┐
│                  FASTAPI BACKEND                      │
│   /api/chat  ·  /api/agent  ·  /health               │
│                                                       │
│   ChatbotEngine → SchoolWorkflow → SQLite DB          │
└──────────────────────────────────────────────────────┘
```

**Two repositories used as foundation:**
- Frontend: `octoi/wb-ui-clone` (WhatsApp Flutter UI)
- Backend: `botdev-community/whatsapp-bot-starter` (FastAPI chatbot)

---

## Quick Start

### 1. Start the Backend

```bash
cd whatsapp-prototype/backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Verify: http://localhost:8000/health → `{"status": "healthy"}`
API docs: http://localhost:8000/docs

### 2. Run the Flutter App

```bash
cd whatsapp-prototype/flutter
flutter pub get
flutter run
```

> **Note on API URL:**
> - Web / Desktop / iOS Simulator → `http://localhost:8000` ✅ (default)
> - Android Emulator → change `_base` in `lib/services/chatbot_api.dart` to `http://10.0.2.2:8000`
> - Physical device → use your machine's LAN IP, e.g. `http://192.168.1.x:8000`

---

## Demo Flow

### Full End-to-End Demo (15 steps)

| # | Action | Expected |
|---|--------|----------|
| 1 | Launch app | Mode selection screen |
| 2 | Tap **User Mode** | Organisation search |
| 3 | Search "Sunrise" | School appears with ✓ |
| 4 | Tap school | WhatsApp chat opens |
| 5 | Bot greets automatically | School welcome message |
| 6 | Type "attendance" | Child selection buttons |
| 7 | Tap child name | Attendance: 90% shown |
| 8 | Type "homework" | Today's homework by subject |
| 9 | Type "fees" | Fee balance with ₹ amounts |
| 10 | Type "I want to talk to someone" | Agent request confirmation |
| 11 | Go back → **Business Mode** | Setup screen (first time) |
| 12 | Complete setup, enter home | **Agent Requests: 1** badge visible |
| 13 | Tap Requests tab → open conv | See conversation + "Intervene" button |
| 14 | Tap **Intervene** | Status → INTERVENED, type as agent |
| 15 | Tap **Leave** | Status → ATTENDED |

---

## Prototype Data

### Users (Parents)
| ID | Name | Children |
|----|------|----------|
| user_001 | Priya Sharma | Aarav (Gr.1), Ananya (Gr.5) |
| user_002 | Rahul Verma | Rohan (KG) |
| user_003 | Anita Singh | Priya (Gr.8), Karan (Gr.10) |
| user_004 | Deepak Patel | Aditya (Gr.11 Sci) |

### Students
| Code | Name | Class | Attendance |
|------|------|-------|------------|
| STU001 | Aarav Sharma | Grade 1-A | 90% |
| STU002 | Ananya Sharma | Grade 5-A | ~95% |
| STU003 | Rohan Verma | KG-A | ~85% |
| STU004 | Priya Singh | Grade 8-A | 100% |
| STU005 | Karan Singh | Grade 10-A | ~80% |
| STU006 | Aditya Patel | Grade 11 Science-A | ~95% |

### Fee Status
| Student | Total | Paid | Status |
|---------|-------|------|--------|
| Aarav | ₹18,000 | ₹9,000 | Partial |
| Ananya | ₹20,000 | ₹20,000 | Paid ✅ |
| Rohan | ₹15,000 | ₹0 | Pending ❌ |

---

## Chatbot Capabilities

| Service | Trigger words |
|---------|---------------|
| Child Info | "child", "student", "details" |
| Attendance | "attendance", "present", "absent" |
| Homework | "homework", "assignment", "hw" |
| Exam Results | "result", "marks", "score" |
| Exam Schedule | "exam", "schedule", "timetable" |
| Fee Status | "fee", "fees", "payment", "balance" |
| Transport | "transport", "bus", "route" |
| School Info | "school", "timing", "contact", "address" |
| Agent | "agent", "human", "person", "representative", "talk to someone" |

---

## Conversation States

```
BOT_ACTIVE       → Bot handles all messages
WAITING_FOR_AGENT → User requested human; business sees notification
INTERVENED       → Agent has taken over; bot is paused
ATTENDED         → Agent has left; conversation closed
```

---

## API Reference

### Chat (User Side)
```
GET  /health
GET  /api/chat/organizations?q=<query>
GET  /api/chat/organizations/<id>
POST /api/chat          { session_id, organization_id, message }
GET  /api/chat/history/<conv_id>
```

### Agent (Business Side)
```
POST /api/agent/profile
GET  /api/agent/profile/<org_id>
GET  /api/agent/conversations/<org_id>
GET  /api/agent/requests/<org_id>
GET  /api/agent/requests/<org_id>/count
GET  /api/agent/active/<org_id>
GET  /api/agent/attended/<org_id>
GET  /api/agent/conversation/<conv_id>/messages
POST /api/agent/conversations/<conv_id>/intervene
POST /api/agent/conversations/<conv_id>/leave
POST /api/agent/conversations/<conv_id>/message
```

---

## Phase 2 Customisation (Adding a New Institution)

To deploy for a different institution (hospital, college, etc.):

1. **Replace chatbot logic:** Edit `backend/app/services/school_workflow.py`
   - Implement `handle_async()` with new menus, intents, and data fetchers
   - Update `AGENT_TRIGGERS` list

2. **Replace seed data:** Edit `backend/app/services/database.py`
   - Update `_seed_data()` with institution-specific records
   - Add/remove tables as needed

3. **Flutter stays unchanged** — no UI code needs modification

The platform (Flutter UI + FastAPI engine + agent system) is fully reusable.

---

## Project Structure

```
whatsapp-prototype/
├── backend/
│   ├── requirements.txt
│   └── app/
│       ├── main.py                    # FastAPI app entry point
│       ├── models/schemas.py          # Pydantic request/response models
│       ├── routers/
│       │   ├── chat.py                # User-side API
│       │   └── agent.py               # Business-side API
│       ├── services/
│       │   ├── database.py            # SQLite + school data
│       │   ├── chatbot_engine.py      # Stateless engine (platform)
│       │   ├── school_workflow.py     # School logic (replaceable)
│       │   ├── conversation_service.py
│       │   └── agent_service.py
│       └── data/
│           └── prototype.db           # Auto-created on first run
│
└── flutter/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── theme/whatsapp_theme.dart
        ├── models/models.dart
        ├── services/
        │   ├── chatbot_api.dart
        │   └── app_state.dart
        ├── screens/
        │   ├── mode_selection_screen.dart
        │   ├── business_setup_screen.dart
        │   ├── business_home_screen.dart
        │   ├── business_chat_screen.dart
        │   ├── organization_search_screen.dart
        │   └── chat_screen.dart
        └── widgets/
            ├── message_bubble.dart
            └── conversation_list_item.dart
```

---

## No External Dependencies Required

- ✅ No Meta / WhatsApp credentials
- ✅ No MongoDB
- ✅ No Redis
- ✅ No cloud services
- ✅ No internet connection (after `flutter pub get`)
- ✅ SQLite database auto-created on first run
- ✅ Prototype data seeded automatically
