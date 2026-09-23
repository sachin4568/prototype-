"""
Local SQLite Database Service — Phase 2 (School Edition)
Adds school tables: classes, sections, teachers, students,
attendance, homework, exams, exam_schedule, marks, fees, transport.
All existing tables and API contracts are preserved.
"""

import aiosqlite
import json
import uuid
from datetime import datetime
from typing import Dict, List, Optional
from pathlib import Path

DB_PATH = str(Path(__file__).parent.parent / "data" / "prototype.db")


def _now_iso() -> str:
    return datetime.utcnow().isoformat()


class Database:

    # ─────────────────────────── INIT ────────────────────────────────────

    async def initialise(self):
        Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
        async with aiosqlite.connect(DB_PATH) as db:
            await db.executescript("""
                PRAGMA foreign_keys = ON;

                -- Platform tables (unchanged from Phase 1) ──────────────
                CREATE TABLE IF NOT EXISTS organizations (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    category TEXT DEFAULT 'Organization',
                    description TEXT DEFAULT '',
                    verified INTEGER DEFAULT 0,
                    avatar_color TEXT DEFAULT '#075E54',
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS users (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    phone TEXT,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS conversations (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    user_id TEXT NOT NULL,
                    state TEXT DEFAULT 'BOT_ACTIVE',
                    chatbot_state TEXT DEFAULT 'START',
                    chatbot_data TEXT DEFAULT '{}',
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS messages (
                    id TEXT PRIMARY KEY,
                    conversation_id TEXT NOT NULL,
                    sender_id TEXT NOT NULL,
                    sender_type TEXT NOT NULL,
                    text TEXT NOT NULL,
                    message_type TEXT DEFAULT 'TEXT',
                    metadata TEXT DEFAULT '{}',
                    status TEXT DEFAULT 'SENT',
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS business_profiles (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    verified INTEGER DEFAULT 0,
                    description TEXT DEFAULT '',
                    category TEXT DEFAULT 'Education',
                    avatar_color TEXT DEFAULT '#075E54',
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );

                -- School-specific tables ──────────────────────────────────
                CREATE TABLE IF NOT EXISTS school_config (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    school_name TEXT NOT NULL,
                    address TEXT DEFAULT '',
                    phone TEXT DEFAULT '',
                    email TEXT DEFAULT '',
                    website TEXT DEFAULT '',
                    office_hours TEXT DEFAULT '8:00 AM – 4:00 PM',
                    classes_info TEXT DEFAULT 'KG – Grade 12',
                    academic_year TEXT DEFAULT '2026-27'
                );
                CREATE TABLE IF NOT EXISTS teachers (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    subject TEXT DEFAULT '',
                    phone TEXT DEFAULT '',
                    email TEXT DEFAULT ''
                );
                CREATE TABLE IF NOT EXISTS classes (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    class_name TEXT NOT NULL,
                    stream TEXT DEFAULT ''
                );
                CREATE TABLE IF NOT EXISTS sections (
                    id TEXT PRIMARY KEY,
                    class_id TEXT NOT NULL,
                    section_name TEXT NOT NULL,
                    class_teacher_id TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS students (
                    id TEXT PRIMARY KEY,
                    student_code TEXT NOT NULL,
                    organization_id TEXT NOT NULL,
                    user_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    date_of_birth TEXT DEFAULT '',
                    gender TEXT DEFAULT '',
                    class_id TEXT NOT NULL,
                    section_id TEXT NOT NULL,
                    roll_no INTEGER DEFAULT 0
                );
                CREATE TABLE IF NOT EXISTS attendance (
                    id TEXT PRIMARY KEY,
                    student_id TEXT NOT NULL,
                    date TEXT NOT NULL,
                    status TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS homework (
                    id TEXT PRIMARY KEY,
                    class_id TEXT NOT NULL,
                    section_id TEXT NOT NULL,
                    subject TEXT NOT NULL,
                    description TEXT NOT NULL,
                    assigned_date TEXT NOT NULL,
                    due_date TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS exams (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    exam_name TEXT NOT NULL,
                    academic_year TEXT NOT NULL,
                    class_id TEXT NOT NULL,
                    start_date TEXT NOT NULL,
                    end_date TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS exam_schedule (
                    id TEXT PRIMARY KEY,
                    exam_id TEXT NOT NULL,
                    subject TEXT NOT NULL,
                    exam_date TEXT NOT NULL,
                    start_time TEXT NOT NULL,
                    end_time TEXT NOT NULL,
                    room_no TEXT DEFAULT ''
                );
                CREATE TABLE IF NOT EXISTS marks (
                    id TEXT PRIMARY KEY,
                    student_id TEXT NOT NULL,
                    schedule_id TEXT NOT NULL,
                    marks_obtained REAL NOT NULL,
                    max_marks REAL NOT NULL
                );
                CREATE TABLE IF NOT EXISTS fees (
                    id TEXT PRIMARY KEY,
                    student_id TEXT NOT NULL,
                    academic_year TEXT NOT NULL,
                    total_fee REAL NOT NULL,
                    paid_amount REAL NOT NULL,
                    pending_amount REAL NOT NULL,
                    status TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS transport (
                    id TEXT PRIMARY KEY,
                    student_id TEXT NOT NULL,
                    route_no TEXT NOT NULL,
                    pickup_point TEXT NOT NULL,
                    transport_fee REAL NOT NULL,
                    status TEXT DEFAULT 'Active'
                );
            """)
            await db.commit()
            await self._seed_data(db)

    # ─────────────────────────── SEED ────────────────────────────────────

    async def _seed_data(self, db):
        cur = await db.execute("SELECT COUNT(*) FROM organizations")
        if (await cur.fetchone())[0] > 0:
            return  # already seeded

        now = _now_iso()

        # ── Organizations ────────────────────────────────────────────────
        orgs = [
            ("org_001","Sunrise International School","K-12 Education",
             "Excellence in education since 1995. Nurturing young minds from KG to Grade 12.",1,"#075E54"),
            ("org_002","City Medical Centre","Healthcare",
             "Quality healthcare for the whole family.",1,"#128C7E"),
            ("org_003","Horizon College","Higher Education",
             "Empowering tomorrow's leaders.",0,"#1a7e3a"),
            ("org_004","TechCorp Support","Business",
             "24/7 customer support for TechCorp products.",1,"#34B7F1"),
            ("org_005","Green Valley Pharmacy","Healthcare",
             "Your trusted neighbourhood pharmacy.",0,"#6b4c9a"),
        ]
        for o in orgs:
            await db.execute("INSERT INTO organizations VALUES (?,?,?,?,?,?,?)", (*o, now))

        # ── School config ────────────────────────────────────────────────
        await db.execute("INSERT INTO school_config VALUES (?,?,?,?,?,?,?,?,?,?)", (
            "cfg_001","org_001","Sunrise International School",
            "14 Sunrise Marg, Education City, New Delhi – 110001",
            "+91-11-2345-6789","info@sunriseschool.edu.in",
            "www.sunriseschool.edu.in",
            "Monday – Friday: 8:00 AM – 4:00 PM\nSaturday: 9:00 AM – 1:00 PM",
            "KG – Grade 12","2026-27"
        ))

        # ── Users (parents) ──────────────────────────────────────────────
        users = [
            ("user_001","Priya Sharma",   "+91-9876543210"),
            ("user_002","Rahul Verma",    "+91-9123456789"),
            ("user_003","Anita Singh",    "+91-9988776655"),
            ("user_004","Deepak Patel",   "+91-9871234567"),
        ]
        for u in users:
            await db.execute("INSERT INTO users VALUES (?,?,?,?)", (*u, now))

        # ── Teachers ──────────────────────────────────────────────────────
        teachers = [
            ("tch_001","org_001","Neha Verma",    "Class Teacher / English", "+91-9801010101","neha@sunriseschool.edu.in"),
            ("tch_002","org_001","Rajiv Khanna",  "Mathematics",             "+91-9802020202","rajiv@sunriseschool.edu.in"),
            ("tch_003","org_001","Sunita Rao",    "Class Teacher / Science", "+91-9803030303","sunita@sunriseschool.edu.in"),
            ("tch_004","org_001","Amir Khan",     "Social Science",          "+91-9804040404","amir@sunriseschool.edu.in"),
            ("tch_005","org_001","Meera Joshi",   "Class Teacher / Physics", "+91-9805050505","meera@sunriseschool.edu.in"),
            ("tch_006","org_001","Arjun Nair",    "Chemistry",               "+91-9806060606","arjun@sunriseschool.edu.in"),
            ("tch_007","org_001","Preethi Iyer",  "Class Teacher / Commerce","+91-9807070707","preethi@sunriseschool.edu.in"),
            ("tch_008","org_001","Sanjay Gupta",  "Accountancy",             "+91-9808080808","sanjay@sunriseschool.edu.in"),
        ]
        for t in teachers:
            await db.execute("INSERT INTO teachers VALUES (?,?,?,?,?,?)", t)

        # ── Classes ───────────────────────────────────────────────────────
        classes = [
            ("cls_kg",  "org_001","KG",      ""),
            ("cls_1",   "org_001","Grade 1",  ""),
            ("cls_5",   "org_001","Grade 5",  ""),
            ("cls_8",   "org_001","Grade 8",  ""),
            ("cls_10",  "org_001","Grade 10", ""),
            ("cls_11s", "org_001","Grade 11", "Science"),
            ("cls_11c", "org_001","Grade 11", "Commerce"),
            ("cls_12s", "org_001","Grade 12", "Science"),
            ("cls_12h", "org_001","Grade 12", "Humanities"),
        ]
        for c in classes:
            await db.execute("INSERT INTO classes VALUES (?,?,?,?)", c)

        # ── Sections ──────────────────────────────────────────────────────
        # (section_id, class_id, section_name, class_teacher_id)
        sections = [
            ("sec_kg_a",  "cls_kg",  "A","tch_001"),
            ("sec_1_a",   "cls_1",   "A","tch_001"),
            ("sec_1_b",   "cls_1",   "B","tch_002"),
            ("sec_5_a",   "cls_5",   "A","tch_003"),
            ("sec_8_a",   "cls_8",   "A","tch_004"),
            ("sec_10_a",  "cls_10",  "A","tch_003"),
            ("sec_11s_a", "cls_11s", "A","tch_005"),
            ("sec_11c_a", "cls_11c", "A","tch_007"),
            ("sec_12s_a", "cls_12s", "A","tch_005"),
            ("sec_12h_a", "cls_12h", "A","tch_007"),
        ]
        for s in sections:
            await db.execute("INSERT INTO sections VALUES (?,?,?,?)", s)

        # ── Students ─────────────────────────────────────────────────────
        # (id, code, org, user_id, name, dob, gender, class_id, section_id, roll)
        students = [
            # user_001 → Priya Sharma has two children
            ("stu_001","STU001","org_001","user_001","Aarav Sharma",
             "2019-06-15","Male","cls_1","sec_1_a",1),
            ("stu_002","STU002","org_001","user_001","Ananya Sharma",
             "2017-03-22","Female","cls_5","sec_5_a",5),
            # user_002 → Rahul Verma one child
            ("stu_003","STU003","org_001","user_002","Rohan Verma",
             "2021-09-01","Male","cls_kg","sec_kg_a",3),
            # user_003 → Anita Singh two children
            ("stu_004","STU004","org_001","user_003","Priya Singh",
             "2011-11-10","Female","cls_8","sec_8_a",7),
            ("stu_005","STU005","org_001","user_003","Karan Singh",
             "2008-04-19","Male","cls_10","sec_10_a",12),
            # user_004 → Deepak Patel one child (Grade 11 Science)
            ("stu_006","STU006","org_001","user_004","Aditya Patel",
             "2007-07-30","Male","cls_11s","sec_11s_a",2),
        ]
        for s in students:
            await db.execute("INSERT INTO students VALUES (?,?,?,?,?,?,?,?,?,?)", s)

        # ── Attendance (Sept 2026, 20 school days: 1–10, 15–24) ──────────
        # status: Present / Absent
        attendance_data = [
            # Aarav Sharma (stu_001) — 18 Present, 2 Absent
            ("stu_001","2026-09-05","Absent"), ("stu_001","2026-09-12","Absent"),
        ]
        present_days = [
            "2026-09-01","2026-09-02","2026-09-03","2026-09-04",
            "2026-09-06","2026-09-07","2026-09-08","2026-09-09","2026-09-10",
            "2026-09-15","2026-09-16","2026-09-17","2026-09-18","2026-09-19",
            "2026-09-20","2026-09-21","2026-09-22","2026-09-23",
        ]
        for d in present_days:
            attendance_data.append(("stu_001", d, "Present"))

        # Ananya Sharma (stu_002) — 19 Present, 1 Absent
        attendance_data.append(("stu_002","2026-09-10","Absent"))
        for d in present_days + ["2026-09-04","2026-09-05"]:
            if d not in ["2026-09-10"]:
                attendance_data.append(("stu_002", d, "Present"))

        # Rohan Verma (stu_003) — 17 Present, 3 Absent
        for d in ["2026-09-03","2026-09-08","2026-09-17"]:
            attendance_data.append(("stu_003", d, "Absent"))
        for d in present_days:
            if d not in ["2026-09-03","2026-09-08","2026-09-17"]:
                attendance_data.append(("stu_003", d, "Present"))

        # Priya Singh (stu_004) — 20 Present, 0 Absent
        for d in present_days + ["2026-09-05","2026-09-12"]:
            attendance_data.append(("stu_004", d, "Present"))

        # Karan Singh (stu_005) — 16 Present, 4 Absent
        for d in ["2026-09-01","2026-09-02","2026-09-15","2026-09-16"]:
            attendance_data.append(("stu_005", d, "Absent"))
        for d in present_days:
            if d not in ["2026-09-01","2026-09-02","2026-09-15","2026-09-16"]:
                attendance_data.append(("stu_005", d, "Present"))

        # Aditya Patel (stu_006) — 19 Present, 1 Absent
        attendance_data.append(("stu_006","2026-09-22","Absent"))
        for d in present_days:
            if d != "2026-09-22":
                attendance_data.append(("stu_006", d, "Present"))

        att_id = 1
        for a in attendance_data:
            await db.execute("INSERT INTO attendance VALUES (?,?,?,?)",
                             (f"att_{att_id:04d}", a[0], a[1], a[2]))
            att_id += 1

        # ── Homework (week of 22 Sep 2026) ───────────────────────────────
        homework = [
            # Grade 1 Section A
            ("hw_001","cls_1","sec_1_a","English",
             "Read Chapter 3 of your reader and write 5 new words in your notebook.",
             "2026-09-22","2026-09-23"),
            ("hw_002","cls_1","sec_1_a","Mathematics",
             "Complete Exercises 1–10 from page 45. Show all working.",
             "2026-09-22","2026-09-23"),
            ("hw_003","cls_1","sec_1_a","Science",
             "Revise the topic 'Parts of a Plant'. Draw and label a plant.",
             "2026-09-22","2026-09-24"),
            # Grade 5 Section A
            ("hw_004","cls_5","sec_5_a","English",
             "Write a paragraph (80 words) on 'My favourite season'.",
             "2026-09-22","2026-09-23"),
            ("hw_005","cls_5","sec_5_a","Mathematics",
             "Practice fraction division — Worksheet 7, Q1–15.",
             "2026-09-22","2026-09-24"),
            ("hw_006","cls_5","sec_5_a","Science",
             "Read Chapter 5 (Force and Motion). Answer textbook Q&A.",
             "2026-09-22","2026-09-25"),
            # Grade 8 Section A
            ("hw_007","cls_8","sec_8_a","Mathematics",
             "Solve quadratic equations — Exercise 4.3, Q1–12.",
             "2026-09-22","2026-09-23"),
            ("hw_008","cls_8","sec_8_a","Science",
             "Write notes on 'Cell Division'. Prepare for a class test.",
             "2026-09-22","2026-09-24"),
            # Grade 10 Section A
            ("hw_009","cls_10","sec_10_a","Mathematics",
             "Trigonometry problems — Chapter 8 exercise, Q1–20.",
             "2026-09-22","2026-09-23"),
            ("hw_010","cls_10","sec_10_a","English",
             "Comprehension passage on page 112. Answer all questions.",
             "2026-09-22","2026-09-24"),
            # Grade 11 Science Section A
            ("hw_011","cls_11s","sec_11s_a","Physics",
             "Solve numericals from Chapter 5 (Laws of Motion), Q11–20.",
             "2026-09-22","2026-09-24"),
            ("hw_012","cls_11s","sec_11s_a","Chemistry",
             "Write balanced equations for 10 chemical reactions. Worksheet 3.",
             "2026-09-22","2026-09-25"),
        ]
        for h in homework:
            await db.execute("INSERT INTO homework VALUES (?,?,?,?,?,?,?)", h)

        # ── Exams ─────────────────────────────────────────────────────────
        exams = [
            ("exam_001","org_001","Term 1 Examination","2026-27","cls_1",
             "2026-10-10","2026-10-15"),
            ("exam_002","org_001","Term 1 Examination","2026-27","cls_5",
             "2026-10-10","2026-10-16"),
            ("exam_003","org_001","Term 1 Examination","2026-27","cls_8",
             "2026-10-10","2026-10-17"),
            ("exam_004","org_001","Term 1 Examination","2026-27","cls_10",
             "2026-10-10","2026-10-18"),
            ("exam_005","org_001","Term 1 Examination","2026-27","cls_11s",
             "2026-10-10","2026-10-20"),
        ]
        for e in exams:
            await db.execute("INSERT INTO exams VALUES (?,?,?,?,?,?,?)", e)

        # ── Exam Schedule ─────────────────────────────────────────────────
        schedules = [
            # Grade 1
            ("sch_001","exam_001","English",     "2026-10-10","09:00","10:00","101"),
            ("sch_002","exam_001","Mathematics", "2026-10-12","09:00","10:00","101"),
            ("sch_003","exam_001","Science",     "2026-10-14","09:00","10:00","101"),
            # Grade 5
            ("sch_004","exam_002","English",     "2026-10-10","09:00","11:00","201"),
            ("sch_005","exam_002","Mathematics", "2026-10-12","09:00","11:00","201"),
            ("sch_006","exam_002","Science",     "2026-10-14","09:00","11:00","201"),
            ("sch_007","exam_002","Social Studies","2026-10-16","09:00","11:00","201"),
            # Grade 8
            ("sch_008","exam_003","English",     "2026-10-10","09:00","12:00","301"),
            ("sch_009","exam_003","Mathematics", "2026-10-12","09:00","12:00","301"),
            ("sch_010","exam_003","Science",     "2026-10-14","09:00","12:00","301"),
            ("sch_011","exam_003","Social Science","2026-10-16","09:00","12:00","301"),
            # Grade 10
            ("sch_012","exam_004","English",     "2026-10-10","09:00","12:00","401"),
            ("sch_013","exam_004","Mathematics", "2026-10-12","09:00","12:00","401"),
            ("sch_014","exam_004","Science",     "2026-10-14","09:00","12:00","401"),
            ("sch_015","exam_004","Social Science","2026-10-17","09:00","12:00","401"),
            # Grade 11 Science
            ("sch_016","exam_005","Physics",     "2026-10-10","09:00","12:00","501"),
            ("sch_017","exam_005","Chemistry",   "2026-10-13","09:00","12:00","501"),
            ("sch_018","exam_005","Mathematics", "2026-10-15","09:00","12:00","501"),
            ("sch_019","exam_005","English",     "2026-10-18","09:00","12:00","501"),
        ]
        for s in schedules:
            await db.execute("INSERT INTO exam_schedule VALUES (?,?,?,?,?,?,?)", s)

        # ── Marks (Term 1 results — only for previous term, so use Term 0 concept;
        #    for prototype use Aug 2026 unit test marks stored against same schedules) ──
        # Using prior exam schedules (prefixed p) that already happened in Aug 2026
        prev_schedules = [
            ("psch_001","exam_001","English",     "2026-08-10","09:00","10:00","101"),
            ("psch_002","exam_001","Mathematics", "2026-08-12","09:00","10:00","101"),
            ("psch_003","exam_001","Science",     "2026-08-14","09:00","10:00","101"),
            ("psch_004","exam_002","English",     "2026-08-10","09:00","11:00","201"),
            ("psch_005","exam_002","Mathematics", "2026-08-12","09:00","11:00","201"),
            ("psch_006","exam_002","Science",     "2026-08-14","09:00","11:00","201"),
            ("psch_007","exam_003","English",     "2026-08-10","09:00","12:00","301"),
            ("psch_008","exam_003","Mathematics", "2026-08-12","09:00","12:00","301"),
            ("psch_009","exam_003","Science",     "2026-08-14","09:00","12:00","301"),
        ]
        for s in prev_schedules:
            await db.execute("INSERT INTO exam_schedule VALUES (?,?,?,?,?,?,?)", s)

        marks = [
            # Aarav Sharma (stu_001) — Grade 1 Unit Test
            ("mrk_001","stu_001","psch_001",88,100),
            ("mrk_002","stu_001","psch_002",92,100),
            ("mrk_003","stu_001","psch_003",85,100),
            # Ananya Sharma (stu_002) — Grade 5
            ("mrk_004","stu_002","psch_004",79,100),
            ("mrk_005","stu_002","psch_005",95,100),
            ("mrk_006","stu_002","psch_006",88,100),
            # Priya Singh (stu_004) — Grade 8
            ("mrk_007","stu_004","psch_007",82,100),
            ("mrk_008","stu_004","psch_008",76,100),
            ("mrk_009","stu_004","psch_009",90,100),
        ]
        for m in marks:
            await db.execute("INSERT INTO marks VALUES (?,?,?,?,?)", m)

        # ── Fees ─────────────────────────────────────────────────────────
        fees = [
            ("fee_001","stu_001","2026-27",18000,9000,9000,"Partial"),
            ("fee_002","stu_002","2026-27",20000,20000,0,"Paid"),
            ("fee_003","stu_003","2026-27",15000,0,15000,"Pending"),
            ("fee_004","stu_004","2026-27",22000,11000,11000,"Partial"),
            ("fee_005","stu_005","2026-27",22000,22000,0,"Paid"),
            ("fee_006","stu_006","2026-27",28000,14000,14000,"Partial"),
        ]
        for f in fees:
            await db.execute("INSERT INTO fees VALUES (?,?,?,?,?,?,?)", f)

        # ── Transport ────────────────────────────────────────────────────
        transport = [
            ("trn_001","stu_001","R01","Main Road Junction",2500,"Active"),
            ("trn_002","stu_002","R01","Main Road Junction",2500,"Active"),
            ("trn_004","stu_004","R03","Green Park Gate",2800,"Active"),
            ("trn_005","stu_005","R03","Green Park Gate",2800,"Active"),
            # stu_003 and stu_006: no transport (self-transport)
        ]
        for t in transport:
            await db.execute("INSERT INTO transport VALUES (?,?,?,?,?,?)", t)

        await db.commit()

    # ─────────────────────────── PLATFORM METHODS (unchanged) ────────────

    async def get_organizations(self, query: str = "") -> List[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            if query:
                cur = await db.execute(
                    "SELECT * FROM organizations WHERE LOWER(name) LIKE ?",
                    (f"%{query.lower()}%",))
            else:
                cur = await db.execute("SELECT * FROM organizations")
            return [dict(r) for r in await cur.fetchall()]

    async def get_organization(self, org_id: str) -> Optional[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("SELECT * FROM organizations WHERE id=?", (org_id,))
            row = await cur.fetchone()
            return dict(row) if row else None

    async def upsert_business_profile(self, data: Dict) -> Dict:
        org_id, now = data["organization_id"], _now_iso()
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute(
                "SELECT * FROM business_profiles WHERE organization_id=?", (org_id,))
            existing = await cur.fetchone()
            if existing:
                await db.execute(
                    "UPDATE business_profiles SET name=?,verified=?,description=?,category=?,avatar_color=?,updated_at=? WHERE organization_id=?",
                    (data["name"],int(data.get("verified",0)),data.get("description",""),
                     data.get("category","Education"),data.get("avatar_color","#075E54"),now,org_id))
                bp_id = existing["id"]
            else:
                bp_id = str(uuid.uuid4())
                await db.execute("INSERT INTO business_profiles VALUES (?,?,?,?,?,?,?,?,?)",
                    (bp_id,org_id,data["name"],int(data.get("verified",0)),
                     data.get("description",""),data.get("category","Education"),
                     data.get("avatar_color","#075E54"),now,now))
                await db.execute(
                    "UPDATE organizations SET name=?,verified=?,avatar_color=? WHERE id=?",
                    (data["name"],int(data.get("verified",0)),data.get("avatar_color","#075E54"),org_id))
            await db.commit()
            cur2 = await db.execute("SELECT * FROM business_profiles WHERE id=?", (bp_id,))
            return dict(await cur2.fetchone())

    async def get_business_profile(self, org_id: str) -> Optional[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute(
                "SELECT * FROM business_profiles WHERE organization_id=?", (org_id,))
            row = await cur.fetchone()
            return dict(row) if row else None

    async def get_or_create_conversation(self, org_id: str, user_id: str) -> Dict:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute(
                "SELECT * FROM conversations WHERE organization_id=? AND user_id=?",
                (org_id, user_id))
            row = await cur.fetchone()
            if row:
                return dict(row)
            now, cid = _now_iso(), str(uuid.uuid4())
            await db.execute("INSERT INTO conversations VALUES (?,?,?,?,?,?,?,?)",
                (cid,org_id,user_id,"BOT_ACTIVE","START","{}",now,now))
            await db.commit()
            return {"id":cid,"organization_id":org_id,"user_id":user_id,
                    "state":"BOT_ACTIVE","chatbot_state":"START",
                    "chatbot_data":"{}","created_at":now,"updated_at":now}

    async def get_conversation(self, conv_id: str) -> Optional[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("SELECT * FROM conversations WHERE id=?", (conv_id,))
            row = await cur.fetchone()
            return dict(row) if row else None

    async def update_conversation_state(self, conv_id: str,
                                         state=None, chatbot_state=None, chatbot_data=None):
        async with aiosqlite.connect(DB_PATH) as db:
            updates, params = [], []
            if state:         updates.append("state=?");         params.append(state)
            if chatbot_state: updates.append("chatbot_state=?"); params.append(chatbot_state)
            if chatbot_data is not None:
                updates.append("chatbot_data=?"); params.append(json.dumps(chatbot_data))
            updates.append("updated_at=?"); params.append(_now_iso())
            params.append(conv_id)
            await db.execute(f"UPDATE conversations SET {', '.join(updates)} WHERE id=?", params)
            await db.commit()

    async def get_org_conversations(self, org_id: str) -> List[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("""
                SELECT c.*, u.name AS user_name, u.phone AS user_phone
                FROM conversations c JOIN users u ON c.user_id=u.id
                WHERE c.organization_id=? ORDER BY c.updated_at DESC
            """, (org_id,))
            return [dict(r) for r in await cur.fetchall()]

    async def save_message(self, data: Dict) -> Dict:
        mid, now = data.get("id", str(uuid.uuid4())), _now_iso()
        async with aiosqlite.connect(DB_PATH) as db:
            await db.execute("INSERT INTO messages VALUES (?,?,?,?,?,?,?,?,?)",
                (mid,data["conversation_id"],data["sender_id"],data["sender_type"],
                 data["text"],data.get("message_type","TEXT"),
                 json.dumps(data.get("metadata",{})),data.get("status","SENT"),now))
            await db.commit()
        return {**data,"id":mid,"created_at":now}

    async def get_conversation_messages(self, conv_id: str) -> List[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute(
                "SELECT * FROM messages WHERE conversation_id=? ORDER BY created_at ASC",
                (conv_id,))
            result = []
            for r in await cur.fetchall():
                d = dict(r); d["metadata"] = json.loads(d.get("metadata","{}"))
                result.append(d)
            return result

    async def get_last_message(self, conv_id: str) -> Optional[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute(
                "SELECT * FROM messages WHERE conversation_id=? ORDER BY created_at DESC LIMIT 1",
                (conv_id,))
            row = await cur.fetchone()
            if not row: return None
            d = dict(row); d["metadata"] = json.loads(d.get("metadata","{}"))
            return d

    async def get_user(self, user_id: str) -> Optional[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("SELECT * FROM users WHERE id=?", (user_id,))
            row = await cur.fetchone()
            return dict(row) if row else None

    async def ping(self) -> bool:
        try:
            async with aiosqlite.connect(DB_PATH) as db:
                await db.execute("SELECT 1")
            return True
        except Exception:
            return False

    # ─────────────────────────── SCHOOL METHODS ──────────────────────────

    async def get_school_config(self, org_id: str) -> Optional[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("SELECT * FROM school_config WHERE organization_id=?", (org_id,))
            row = await cur.fetchone()
            return dict(row) if row else None

    async def get_students_for_user(self, user_id: str, org_id: str) -> List[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("""
                SELECT s.*,
                       c.class_name, c.stream,
                       sec.section_name,
                       t.name AS teacher_name, t.subject AS teacher_subject
                FROM students s
                JOIN classes c ON s.class_id=c.id
                JOIN sections sec ON s.section_id=sec.id
                JOIN teachers t ON sec.class_teacher_id=t.id
                WHERE s.user_id=? AND s.organization_id=?
            """, (user_id, org_id))
            return [dict(r) for r in await cur.fetchall()]

    async def get_student_by_id(self, student_id: str) -> Optional[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("""
                SELECT s.*,
                       c.class_name, c.stream,
                       sec.section_name,
                       t.name AS teacher_name, t.subject AS teacher_subject,
                       t.email AS teacher_email
                FROM students s
                JOIN classes c ON s.class_id=c.id
                JOIN sections sec ON s.section_id=sec.id
                JOIN teachers t ON sec.class_teacher_id=t.id
                WHERE s.id=?
            """, (student_id,))
            row = await cur.fetchone()
            return dict(row) if row else None

    async def get_attendance(self, student_id: str) -> List[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute(
                "SELECT * FROM attendance WHERE student_id=? ORDER BY date DESC",
                (student_id,))
            return [dict(r) for r in await cur.fetchall()]

    async def get_homework(self, class_id: str, section_id: str) -> List[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("""
                SELECT * FROM homework
                WHERE class_id=? AND section_id=?
                ORDER BY assigned_date DESC, subject ASC
                LIMIT 10
            """, (class_id, section_id))
            return [dict(r) for r in await cur.fetchall()]

    async def get_exam_schedule(self, class_id: str) -> List[Dict]:
        """Return upcoming exam schedule for a class (joined with exam name)."""
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("""
                SELECT es.*, e.exam_name, e.academic_year
                FROM exam_schedule es
                JOIN exams e ON es.exam_id=e.id
                WHERE e.class_id=?
                ORDER BY es.exam_date ASC
            """, (class_id,))
            return [dict(r) for r in await cur.fetchall()]

    async def get_marks(self, student_id: str) -> List[Dict]:
        """Return most recent marks for a student."""
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("""
                SELECT m.*, es.subject, es.exam_date, e.exam_name
                FROM marks m
                JOIN exam_schedule es ON m.schedule_id=es.id
                JOIN exams e ON es.exam_id=e.id
                WHERE m.student_id=?
                ORDER BY es.exam_date DESC
            """, (student_id,))
            return [dict(r) for r in await cur.fetchall()]

    async def get_fees(self, student_id: str) -> Optional[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute(
                "SELECT * FROM fees WHERE student_id=? ORDER BY academic_year DESC LIMIT 1",
                (student_id,))
            row = await cur.fetchone()
            return dict(row) if row else None

    async def get_transport(self, student_id: str) -> Optional[Dict]:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cur = await db.execute("SELECT * FROM transport WHERE student_id=?", (student_id,))
            row = await cur.fetchone()
            return dict(row) if row else None
