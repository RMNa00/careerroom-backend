-- =====================================================================
-- careerroom DATABASE SCHEMA (PostgreSQL)
-- Dibuat berdasarkan mockup / mock data web app careerroom
-- (career_user, mentor, recruiter/company, admin ecosystem)
-- =====================================================================
-- Cara pakai di pgAdmin:
-- 1. Buat database baru, misal: careerroom_db
-- 2. Buka Query Tool pada database tsb
-- 3. Paste seluruh isi file ini, lalu Execute (F5)
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- EXTENSIONS
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- untuk gen_random_uuid()

-- ---------------------------------------------------------------------
-- ENUM TYPES
-- ---------------------------------------------------------------------
CREATE TYPE user_role AS ENUM ('career_user', 'mentor', 'recruiter', 'admin');
CREATE TYPE subscription_plan AS ENUM ('FREE', 'PRO', 'CAREER_PLUS');
CREATE TYPE experience_level AS ENUM ('Beginner', 'Junior', 'Mid', 'Senior', 'Expert');

CREATE TYPE roadmap_status AS ENUM ('Locked', 'Not Started', 'In Progress', 'Completed');
CREATE TYPE course_difficulty AS ENUM ('Beginner', 'Beginner to Intermediate', 'Intermediate', 'Advanced');

CREATE TYPE job_work_type AS ENUM ('Full-time', 'Part-time', 'Internship', 'Contract', 'Freelance');
CREATE TYPE application_status AS ENUM ('Applied', 'In Review', 'Interview', 'Offered', 'Rejected', 'Withdrawn');

CREATE TYPE freelance_project_status AS ENUM ('Open', 'In Progress', 'Completed', 'Cancelled');
CREATE TYPE proposal_status AS ENUM ('Submitted', 'Accepted', 'Rejected', 'Withdrawn');
CREATE TYPE contract_status AS ENUM ('Active Work', 'In Review', 'Completed', 'Disputed', 'Cancelled');

CREATE TYPE booking_status AS ENUM ('Pending', 'Confirmed', 'Completed', 'Cancelled');
CREATE TYPE notification_type AS ENUM ('job', 'mentor', 'academy', 'community', 'freelance', 'system');
CREATE TYPE payment_status AS ENUM ('Pending', 'Paid', 'Failed', 'Refunded');
CREATE TYPE payment_item_type AS ENUM ('subscription', 'course', 'mentor_session', 'portfolio_addon', 'freelance_fee');

-- =====================================================================
-- 1. USERS & PROFILE
-- =====================================================================
CREATE TABLE users (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(150) NOT NULL,
    email               VARCHAR(255) NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,
    role                user_role NOT NULL DEFAULT 'career_user',
    avatar_url          TEXT,
    title               VARCHAR(200),                 -- e.g. "Aspiring UI/UX Designer"
    experience_level    experience_level DEFAULT 'Junior',
    target_role         VARCHAR(150),
    overall_progress    SMALLINT DEFAULT 0 CHECK (overall_progress BETWEEN 0 AND 100),
    plan                subscription_plan NOT NULL DEFAULT 'FREE',
    bio                 TEXT,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Skill master list (agar tidak duplikat nama skill antar tabel)
CREATE TABLE skills (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    category    VARCHAR(50)              -- Design, Development, Soft Skills, dst.
);

-- Skill milik user (many-to-many + level + verified)
CREATE TABLE user_skills (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_id    INT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    level       SMALLINT NOT NULL DEFAULT 0 CHECK (level BETWEEN 0 AND 100),
    verified    BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (user_id, skill_id)
);

-- Skill gap / rekomendasi yang perlu dipelajari user
CREATE TABLE user_skill_gaps (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_name  VARCHAR(150) NOT NULL
);

-- Statistik ringkas per user (courses completed, jam belajar, dsb)
CREATE TABLE user_stats (
    user_id                     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    courses_completed           INT DEFAULT 0,
    learning_hours              INT DEFAULT 0,
    projects_built              INT DEFAULT 0,
    jobs_applied                INT DEFAULT 0,
    interviews_scheduled        INT DEFAULT 0,
    freelance_earned            NUMERIC(14,2) DEFAULT 0,
    mentor_sessions_completed   INT DEFAULT 0,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 2. MENTORS
-- =====================================================================
CREATE TABLE mentors (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL, -- akun mentor (opsional)
    name            VARCHAR(150) NOT NULL,
    photo_url       TEXT,
    title           VARCHAR(200),
    company         VARCHAR(150),
    experience_text VARCHAR(50),         -- "10+ Years"
    rating          NUMERIC(3,2) DEFAULT 0,
    reviews_count   INT DEFAULT 0,
    price           NUMERIC(12,2) NOT NULL DEFAULT 0,   -- harga per sesi (Rupiah)
    category        VARCHAR(50),          -- Design, Technology, Business
    bio             TEXT,
    zoom_url        TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE mentor_expertise (
    id          SERIAL PRIMARY KEY,
    mentor_id   UUID NOT NULL REFERENCES mentors(id) ON DELETE CASCADE,
    expertise   VARCHAR(150) NOT NULL
);

CREATE TABLE mentor_availability (
    id              SERIAL PRIMARY KEY,
    mentor_id       UUID NOT NULL REFERENCES mentors(id) ON DELETE CASCADE,
    slot_label      VARCHAR(50) NOT NULL,     -- "Today 15:00", "Tomorrow 10:00"
    slot_datetime   TIMESTAMPTZ              -- opsional, versi lebih presisi
);

CREATE TABLE mentor_bookings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mentor_id       UUID NOT NULL REFERENCES mentors(id) ON DELETE CASCADE,
    scheduled_at    TIMESTAMPTZ NOT NULL,
    status          booking_status NOT NULL DEFAULT 'Pending',
    price_paid      NUMERIC(12,2),
    zoom_url        TEXT,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Chat log pada Virtual Mentoring Room
CREATE TABLE mentoring_messages (
    id              BIGSERIAL PRIMARY KEY,
    booking_id      UUID NOT NULL REFERENCES mentor_bookings(id) ON DELETE CASCADE,
    sender          VARCHAR(20) NOT NULL CHECK (sender IN ('mentor', 'user')),
    message         TEXT NOT NULL,
    sent_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 3. CAREER ROADMAP
-- =====================================================================
CREATE TABLE roadmap_phases (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phase_number            SMALLINT NOT NULL,
    title                   VARCHAR(200) NOT NULL,
    description             TEXT,
    is_template             BOOLEAN NOT NULL DEFAULT TRUE   -- template master (bukan progres per-user)
);

CREATE TABLE roadmap_phase_required_skills (
    id              SERIAL PRIMARY KEY,
    phase_id        UUID NOT NULL REFERENCES roadmap_phases(id) ON DELETE CASCADE,
    skill_name      VARCHAR(150) NOT NULL
);

CREATE TABLE roadmap_tasks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phase_id        UUID NOT NULL REFERENCES roadmap_phases(id) ON DELETE CASCADE,
    title           VARCHAR(255) NOT NULL,
    sort_order      SMALLINT DEFAULT 0
);

-- Progres roadmap per-user (status & progress adalah milik user, bukan template global)
CREATE TABLE user_roadmap_progress (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phase_id        UUID NOT NULL REFERENCES roadmap_phases(id) ON DELETE CASCADE,
    status          roadmap_status NOT NULL DEFAULT 'Locked',
    progress        SMALLINT NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
    recommended_course_id UUID,   -- FK ditambahkan setelah tabel courses dibuat
    UNIQUE (user_id, phase_id)
);

CREATE TABLE user_roadmap_task_status (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id         UUID NOT NULL REFERENCES roadmap_tasks(id) ON DELETE CASCADE,
    done            BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at    TIMESTAMPTZ,
    UNIQUE (user_id, task_id)
);

-- =====================================================================
-- 4. ACADEMY: COURSES, MODULES, QUIZ, ENROLLMENT, CERTIFICATES
-- =====================================================================
CREATE TABLE courses (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(255) NOT NULL,
    category        VARCHAR(50),
    instructor      VARCHAR(150),
    rating          NUMERIC(3,2) DEFAULT 0,
    students_count  INT DEFAULT 0,
    duration_text   VARCHAR(100),          -- "14 Hours - 32 Lessons"
    difficulty      course_difficulty DEFAULT 'Beginner',
    price           NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_free         BOOLEAN NOT NULL DEFAULT FALSE,
    thumbnail_url   TEXT,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_roadmap_progress
    ADD CONSTRAINT fk_recommended_course
    FOREIGN KEY (recommended_course_id) REFERENCES courses(id) ON DELETE SET NULL;

CREATE TABLE course_modules (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title           VARCHAR(255) NOT NULL,
    video_url       TEXT,
    duration_text   VARCHAR(50),
    sort_order      SMALLINT DEFAULT 0
);

CREATE TABLE course_quiz_questions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    question        TEXT NOT NULL,
    correct_option_index SMALLINT NOT NULL
);

CREATE TABLE course_quiz_options (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id     UUID NOT NULL REFERENCES course_quiz_questions(id) ON DELETE CASCADE,
    option_index    SMALLINT NOT NULL,
    option_text     TEXT NOT NULL
);

CREATE TABLE course_enrollments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    progress        SMALLINT NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
    is_completed    BOOLEAN NOT NULL DEFAULT FALSE,
    enrolled_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    UNIQUE (user_id, course_id)
);

CREATE TABLE certificates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    course_id       UUID REFERENCES courses(id) ON DELETE SET NULL,
    title           VARCHAR(255) NOT NULL,
    issuer          VARCHAR(150) DEFAULT 'careerroom Academy',
    issued_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    badge           VARCHAR(50)             -- Gold, Verified, dst.
);

-- =====================================================================
-- 5. JOBS & APPLICATIONS (untuk Recruiter/Company Dashboard)
-- =====================================================================
CREATE TABLE companies (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,   -- akun recruiter pemilik
    name            VARCHAR(150) NOT NULL,
    logo_url        TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE jobs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          UUID REFERENCES companies(id) ON DELETE CASCADE,
    title               VARCHAR(255) NOT NULL,
    company_name        VARCHAR(150) NOT NULL,     -- disimpan juga sebagai teks (denormalized, sesuai mock)
    logo_url            TEXT,
    location            VARCHAR(150),
    work_type           job_work_type NOT NULL DEFAULT 'Full-time',
    salary_text         VARCHAR(150),
    posted_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    description         TEXT,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE job_required_skills (
    id          SERIAL PRIMARY KEY,
    job_id      UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    skill_name  VARCHAR(150) NOT NULL
);

CREATE TABLE job_responsibilities (
    id          SERIAL PRIMARY KEY,
    job_id      UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    sort_order  SMALLINT DEFAULT 0
);

-- Skill match dihitung per user-job (dinamis), disimpan sbg cache/snapshot
CREATE TABLE job_skill_matches (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    job_id          UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    match_percentage SMALLINT CHECK (match_percentage BETWEEN 0 AND 100),
    matching_skills TEXT[],     -- array skill yang cocok
    missing_skills  TEXT[],     -- array skill yang belum dimiliki
    calculated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, job_id)
);

CREATE TABLE job_applications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    job_id          UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    status          application_status NOT NULL DEFAULT 'Applied',
    applied_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, job_id)
);

-- Kandidat pada Company/Recruiter Dashboard (relasi ke job_applications + skor tambahan)
CREATE TABLE candidate_reviews (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id  UUID NOT NULL REFERENCES job_applications(id) ON DELETE CASCADE,
    reviewer_id     UUID REFERENCES users(id) ON DELETE SET NULL,   -- recruiter
    notes           TEXT,
    reviewed_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 6. FREELANCE: PROJECTS, PROPOSALS, CONTRACTS
-- =====================================================================
CREATE TABLE freelance_projects (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_name     VARCHAR(150) NOT NULL,
    client_user_id  UUID REFERENCES users(id) ON DELETE SET NULL,
    title           VARCHAR(255) NOT NULL,
    budget          NUMERIC(14,2) NOT NULL,
    deadline_text   VARCHAR(50),           -- "14 Days"
    description     TEXT,
    status          freelance_project_status NOT NULL DEFAULT 'Open',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE freelance_project_skills (
    id          SERIAL PRIMARY KEY,
    project_id  UUID NOT NULL REFERENCES freelance_projects(id) ON DELETE CASCADE,
    skill_name  VARCHAR(150) NOT NULL
);

CREATE TABLE freelance_proposals (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id      UUID NOT NULL REFERENCES freelance_projects(id) ON DELETE CASCADE,
    freelancer_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cover_letter    TEXT,
    proposed_price  NUMERIC(14,2),
    status          proposal_status NOT NULL DEFAULT 'Submitted',
    submitted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (project_id, freelancer_id)
);

CREATE TABLE freelance_contracts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id          UUID REFERENCES freelance_projects(id) ON DELETE SET NULL,
    freelancer_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_name         VARCHAR(150) NOT NULL,
    project_title       VARCHAR(255) NOT NULL,
    total_amount        NUMERIC(14,2) NOT NULL,
    platform_fee_pct    NUMERIC(5,2) NOT NULL DEFAULT 5,
    platform_fee_amount NUMERIC(14,2) NOT NULL,
    net_earnings        NUMERIC(14,2) NOT NULL,
    status              contract_status NOT NULL DEFAULT 'Active Work',
    deadline            DATE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE freelance_contract_milestones (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id     UUID NOT NULL REFERENCES freelance_contracts(id) ON DELETE CASCADE,
    milestone_label VARCHAR(255) NOT NULL,      -- "1 of 2: Main Home & Product Detail Screen"
    amount          NUMERIC(14,2),
    is_completed    BOOLEAN NOT NULL DEFAULT FALSE,
    is_paid         BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order      SMALLINT DEFAULT 0
);

-- =====================================================================
-- 7. PORTFOLIO
-- =====================================================================
CREATE TABLE portfolio_sections (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,      -- "About Me", "Verified Skills", dst.
    enabled         BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order      SMALLINT DEFAULT 0
);

CREATE TABLE portfolio_projects (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(255) NOT NULL,
    problem         TEXT,
    solution        TEXT,
    image_url       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 8. AI INTERVIEW SIMULATOR
-- =====================================================================
CREATE TABLE interview_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_role     VARCHAR(150),
    overall_score   SMALLINT CHECK (overall_score BETWEEN 0 AND 100),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ
);

CREATE TABLE interview_session_answers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES interview_sessions(id) ON DELETE CASCADE,
    question        TEXT NOT NULL,
    user_answer     TEXT,
    ai_feedback     TEXT,
    score           SMALLINT CHECK (score BETWEEN 0 AND 100),
    sort_order      SMALLINT DEFAULT 0
);

-- =====================================================================
-- 9. COMMUNITY
-- =====================================================================
CREATE TABLE community_posts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category        VARCHAR(50),
    title           VARCHAR(255) NOT NULL,
    content         TEXT,
    image_url       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE community_post_likes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id         UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    liked_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (post_id, user_id)
);

CREATE TABLE community_post_comments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id         UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    author_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Weekly Challenge
CREATE TABLE weekly_challenges (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(255) NOT NULL,
    theme           VARCHAR(255),
    reward_text     VARCHAR(150),        -- "500 careerroom XP + Verified Challenge Badge"
    deadline_at     TIMESTAMPTZ,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE weekly_challenge_participants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id    UUID NOT NULL REFERENCES weekly_challenges(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (challenge_id, user_id)
);

-- =====================================================================
-- 10. NOTIFICATIONS
-- =====================================================================
CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            notification_type NOT NULL DEFAULT 'system',
    title           VARCHAR(255) NOT NULL,
    message         TEXT,
    is_unread       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 11. SUBSCRIPTIONS & PAYMENTS
-- =====================================================================
CREATE TABLE subscription_plans_master (
    id              VARCHAR(30) PRIMARY KEY,     -- 'free' | 'pro' | 'career_plus'
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    price           NUMERIC(12,2) NOT NULL DEFAULT 0,
    period          VARCHAR(20) DEFAULT '/month',
    is_popular      BOOLEAN DEFAULT FALSE
);

CREATE TABLE subscription_plan_features (
    id              SERIAL PRIMARY KEY,
    plan_id         VARCHAR(30) NOT NULL REFERENCES subscription_plans_master(id) ON DELETE CASCADE,
    feature         VARCHAR(255) NOT NULL,
    sort_order      SMALLINT DEFAULT 0
);

CREATE TABLE user_subscriptions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id         VARCHAR(30) NOT NULL REFERENCES subscription_plans_master(id),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

-- Payment / checkout generik (langganan, kursus, sesi mentor, dsb - sesuai PaymentModal)
CREATE TABLE payments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_type       payment_item_type NOT NULL,
    item_reference_id UUID,          -- id ke course/mentor_booking/subscription plan, dsb (polymorphic, tanpa FK ketat)
    item_title      VARCHAR(255) NOT NULL,
    amount          NUMERIC(14,2) NOT NULL,
    status          payment_status NOT NULL DEFAULT 'Pending',
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 12. ADMIN METRICS (materialized snapshot, sesuai ADMIN_METRICS mock)
-- =====================================================================
CREATE TABLE admin_metrics_snapshot (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_date               DATE NOT NULL DEFAULT CURRENT_DATE,
    total_users                 INT DEFAULT 0,
    active_users_monthly        INT DEFAULT 0,
    total_revenue               NUMERIC(16,2) DEFAULT 0,
    course_sales                INT DEFAULT 0,
    mentor_bookings_count       INT DEFAULT 0,
    job_applications_count      INT DEFAULT 0,
    freelance_transactions_count INT DEFAULT 0,
    pro_subscribers             INT DEFAULT 0,
    career_plus_subscribers     INT DEFAULT 0,
    platform_fee_revenue        NUMERIC(16,2) DEFAULT 0
);

-- =====================================================================
-- INDEXES TAMBAHAN UNTUK PERFORMA QUERY UMUM
-- =====================================================================
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_user_skills_user ON user_skills(user_id);
CREATE INDEX idx_mentor_bookings_user ON mentor_bookings(user_id);
CREATE INDEX idx_mentor_bookings_mentor ON mentor_bookings(mentor_id);
CREATE INDEX idx_course_enrollments_user ON course_enrollments(user_id);
CREATE INDEX idx_job_applications_user ON job_applications(user_id);
CREATE INDEX idx_job_applications_job ON job_applications(job_id);
CREATE INDEX idx_freelance_proposals_project ON freelance_proposals(project_id);
CREATE INDEX idx_community_posts_author ON community_posts(author_id);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_unread);
CREATE INDEX idx_payments_user ON payments(user_id);

-- =====================================================================
-- TRIGGER: auto-update kolom updated_at
-- =====================================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_applications_updated_at
    BEFORE UPDATE ON job_applications
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;

-- =====================================================================
-- SEED DATA CONTOH (opsional, sesuai mockData.js agar bisa langsung dites)
-- =====================================================================
BEGIN;

INSERT INTO subscription_plans_master (id, name, description, price, period, is_popular) VALUES
('free', 'Free', 'Baseline plan untuk memulai perjalanan karier', 0, '/month', FALSE),
('pro', 'Pro', 'Akses penuh fitur pembelajaran & AI tools', 49000, '/month', TRUE),
('career_plus', 'Career+', 'Semua fitur Pro plus mentoring & prioritas job matching', 99000, '/month', FALSE);

INSERT INTO users (id, name, email, password_hash, role, avatar_url, title, experience_level, target_role, overall_progress, plan, bio)
VALUES ('11111111-1111-1111-1111-111111111101', 'Alex Rivera', 'alex.rivera@careerroom.dev', 'CHANGE_ME_HASH', 'career_user',
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
        'Aspiring UI/UX Designer & Product Specialist', 'Junior', 'UI/UX Designer', 68, 'PRO',
        'Passionate about human-centric digital interfaces that bridge aesthetics with engineering.');

INSERT INTO user_stats (user_id, courses_completed, learning_hours, projects_built, jobs_applied, interviews_scheduled, freelance_earned, mentor_sessions_completed)
VALUES ('11111111-1111-1111-1111-111111111101', 4, 42, 3, 6, 2, 3500000, 3);

INSERT INTO skills (name, category) VALUES
('Figma', 'Design'), ('UI Design', 'Design'), ('UX Research', 'Design'),
('Prototyping', 'Design'), ('React.js', 'Development'), ('Design System', 'Design'),
('Communication', 'Soft Skills');

INSERT INTO user_skills (user_id, skill_id, level, verified)
SELECT '11111111-1111-1111-1111-111111111101', id,
       CASE name
         WHEN 'Figma' THEN 85 WHEN 'UI Design' THEN 80 WHEN 'UX Research' THEN 62
         WHEN 'Prototyping' THEN 74 WHEN 'React.js' THEN 68 WHEN 'Design System' THEN 70
         WHEN 'Communication' THEN 75 END,
       CASE name WHEN 'UX Research' THEN FALSE ELSE TRUE END
FROM skills;

INSERT INTO mentors (id, name, photo_url, title, company, experience_text, rating, reviews_count, price, category, bio, zoom_url) VALUES
('22222222-2222-2222-2222-222222222201', 'Dr. Maya Lin', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150&auto=format&fit=crop&q=80',
 'Senior Staff Product Designer at TechNova', 'TechNova Inc.', '10+ Years', 4.95, 128, 150000, 'Design',
 'Ex-Google Lead Designer. Mentored over 200+ designers landing roles at top tech companies worldwide.',
 'https://zoom.us/j/9876543210?pwd=careerroomDemoMeeting'),
('22222222-2222-2222-2222-222222222202', 'Budi Santoso', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
 'Head of Engineering at FinPay Asia', 'FinPay Asia', '8 Years', 4.90, 94, 180000, 'Technology',
 'Helping junior developers navigate fullstack engineering careers and system design interviews.',
 'https://zoom.us/j/9876543211?pwd=careerroomDemoMeeting'),
('22222222-2222-2222-2222-222222222203', 'Siti Rahma', 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150&auto=format&fit=crop&q=80',
 'Growth Lead & Product Strategist', 'StartupStudio', '6 Years', 4.88, 76, 120000, 'Business',
 'Scaled top freelance agencies and helped over 50+ freelancers reach 6-figure monthly earnings.',
 'https://zoom.us/j/9876543212?pwd=careerroomDemoMeeting');

INSERT INTO mentor_expertise (mentor_id, expertise) VALUES
('22222222-2222-2222-2222-222222222201', 'Design Systems'),
('22222222-2222-2222-2222-222222222201', 'Portfolio Review'),
('22222222-2222-2222-2222-222222222201', 'UX Research'),
('22222222-2222-2222-2222-222222222201', 'Executive Interview Prep'),
('22222222-2222-2222-2222-222222222202', 'Fullstack Architecture'),
('22222222-2222-2222-2222-222222222202', 'Career Transition'),
('22222222-2222-2222-2222-222222222202', 'Code Reviews'),
('22222222-2222-2222-2222-222222222202', 'System Design'),
('22222222-2222-2222-2222-222222222203', 'Freelancing Business'),
('22222222-2222-2222-2222-222222222203', 'Proposal Strategy'),
('22222222-2222-2222-2222-222222222203', 'Client Pitching'),
('22222222-2222-2222-2222-222222222203', 'Product Management');

INSERT INTO mentor_availability (mentor_id, slot_label) VALUES
('22222222-2222-2222-2222-222222222201', 'Today 15:00'),
('22222222-2222-2222-2222-222222222201', 'Tomorrow 10:00'),
('22222222-2222-2222-2222-222222222201', 'Saturday 14:00'),
('22222222-2222-2222-2222-222222222202', 'Tomorrow 19:00'),
('22222222-2222-2222-2222-222222222202', 'Friday 16:00'),
('22222222-2222-2222-2222-222222222203', 'Today 18:00'),
('22222222-2222-2222-2222-222222222203', 'Thursday 11:00');

INSERT INTO courses (id, title, category, instructor, rating, students_count, duration_text, difficulty, price, is_free, thumbnail_url, description) VALUES
('33333333-3333-3333-3333-333333333301', 'UI/UX Masterclass: From Beginner to Industry Pro', 'Design', 'Dr. Maya Lin', 4.9, 1420, '14 Hours - 32 Lessons', 'Beginner to Intermediate', 0, TRUE,
 NULL, 'Kursus UI/UX dari dasar hingga mahir.'),
('33333333-3333-3333-3333-333333333302', 'Design Systems in Practice', 'Design', 'Dr. Maya Lin', 4.85, 980, '10 Hours - 24 Lessons', 'Intermediate', 199000, FALSE,
 'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?w=500&auto=format&fit=crop&q=80',
 'Learn how to build design tokens, accessible components, and sync Figma styles directly with React production code.'),
('33333333-3333-3333-3333-333333333303', 'AI-Powered Product Development & Rapid Prototyping', 'AI', 'Budi Santoso', 4.88, 1150, '12 Hours - 28 Lessons', 'Intermediate', 149000, FALSE,
 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&auto=format&fit=crop&q=80',
 'Harness modern AI tools like ChatGPT, Claude, and Midjourney to accelerate design research, copy, and web prototypes.');

INSERT INTO course_modules (course_id, title, video_url, duration_text, sort_order) VALUES
('33333333-3333-3333-3333-333333333302', 'Module 1: Design Tokens Architecture', 'https://www.w3schools.com/html/mov_bbb.mp4', '35 min', 1),
('33333333-3333-3333-3333-333333333302', 'Module 2: Component Specifications & Variants', 'https://www.w3schools.com/html/mov_bbb.mp4', '45 min', 2),
('33333333-3333-3333-3333-333333333303', 'Module 1: AI Prompting for Product Managers & Designers', 'https://www.w3schools.com/html/mov_bbb.mp4', '30 min', 1);

INSERT INTO certificates (user_id, title, issuer, issued_date, badge) VALUES
('11111111-1111-1111-1111-111111111101', 'UI/UX Foundations Masterclass', 'careerroom Academy', '2026-08-01', 'Gold'),
('11111111-1111-1111-1111-111111111101', 'Design Systems in Practice', 'careerroom Academy', '2026-09-01', 'Verified');

INSERT INTO roadmap_phases (id, phase_number, title, description) VALUES
('44444444-4444-4444-4444-444444444401', 1, '01 Foundation & Career Orientation', 'Master core visual design principles, color theory, typography, and industry standard tools.'),
('44444444-4444-4444-4444-444444444402', 2, '02 Advanced UI/UX & Design Systems', 'Learn component architecture, auto-layout, tokenization, and multi-platform design systems.'),
('44444444-4444-4444-4444-444444444403', 3, '03 Practical Portfolio & Case Studies', 'Construct 2 end-to-end commercial standard case studies and publish live portfolio.'),
('44444444-4444-4444-4444-444444444404', 4, '04 Job Readiness & AI Interview Prep', 'Optimize CV with AI Analyzer, practice mock interviews, and send targeted job applications.'),
('44444444-4444-4444-4444-444444444405', 5, '05 Freelancing & Client Contract Execution', 'Land first freelance contract, deliver client work, and handle escrow milestone approvals.'),
('44444444-4444-4444-4444-444444444406', 6, '06 Long-term Career Growth & Mentoring', 'Track career analytics, refine advanced skills, and transition into senior leadership.');

INSERT INTO user_roadmap_progress (user_id, phase_id, status, progress, recommended_course_id) VALUES
('11111111-1111-1111-1111-111111111101', '44444444-4444-4444-4444-444444444401', 'Completed', 100, '33333333-3333-3333-3333-333333333301'),
('11111111-1111-1111-1111-111111111101', '44444444-4444-4444-4444-444444444402', 'In Progress', 65, '33333333-3333-3333-3333-333333333302'),
('11111111-1111-1111-1111-111111111101', '44444444-4444-4444-4444-444444444403', 'In Progress', 40, '33333333-3333-3333-3333-333333333303'),
('11111111-1111-1111-1111-111111111101', '44444444-4444-4444-4444-444444444404', 'Not Started', 0, NULL),
('11111111-1111-1111-1111-111111111101', '44444444-4444-4444-4444-444444444405', 'Locked', 0, NULL),
('11111111-1111-1111-1111-111111111101', '44444444-4444-4444-4444-444444444406', 'Locked', 0, NULL);

INSERT INTO jobs (id, title, company_name, logo_url, location, work_type, salary_text, posted_date, description) VALUES
('55555555-5555-5555-5555-555555555501', 'Junior UI/UX Designer', 'TechNova Solutions',
 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=100&auto=format&fit=crop&q=80',
 'Jakarta (Hybrid)', 'Full-time', 'Rp8.000.000 - Rp12.000.000 / month', CURRENT_DATE - INTERVAL '2 day',
 'We are looking for a creative Junior UI/UX Designer to craft beautiful mobile and web apps for top Southeast Asian tech products.'),
('55555555-5555-5555-5555-555555555502', 'Product Designer (Design Systems)', 'FinPay Asia',
 'https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=100&auto=format&fit=crop&q=80',
 'Remote', 'Full-time', 'Rp14.000.000 - Rp20.000.000 / month', CURRENT_DATE - INTERVAL '1 day',
 'FinPay Asia is seeking a dedicated Product Designer focused on design system architecture and component engineering.'),
('55555555-5555-5555-5555-555555555503', 'UX Researcher Intern', 'EduGrowth Startup',
 'https://images.unsplash.com/photo-1572021335469-31706a17aaef?w=100&auto=format&fit=crop&q=80',
 'Bandung (On-site)', 'Internship', 'Rp3.500.000 - Rp5.000.000 / month', CURRENT_DATE - INTERVAL '3 day',
 'Join EduGrowth to conduct exploratory research and gather customer insights for our next-gen learning portal.');

INSERT INTO job_skill_matches (user_id, job_id, match_percentage, matching_skills, missing_skills) VALUES
('11111111-1111-1111-1111-111111111101', '55555555-5555-5555-5555-555555555501', 87,
 ARRAY['Figma','UI Design','Prototyping','Communication'], ARRAY['UX Research']),
('11111111-1111-1111-1111-111111111101', '55555555-5555-5555-5555-555555555502', 92,
 ARRAY['Figma','React.js','Prototyping'], ARRAY['Design System']),
('11111111-1111-1111-1111-111111111101', '55555555-5555-5555-5555-555555555503', 78,
 ARRAY['Figma'], ARRAY['UX Research','User Testing','Data Analysis']);

INSERT INTO freelance_projects (id, client_name, title, budget, deadline_text, description, status) VALUES
('66666666-6666-6666-6666-666666666601', 'Nusantara FinTech', 'Design a Mobile Banking Dashboard App', 5500000, '14 Days',
 'We need an elegant dark-mode mobile banking dashboard prototype with interactive transaction charts, QR transfer, and wallet management screens.', 'Open'),
('66666666-6666-6666-6666-666666666602', 'SaaSify Studio', 'React + Tailwind Landing Page Implementation', 3000000, '5 Days',
 'Convert our Figma design file into clean, responsive React code with subtle micro-animations and Google Fonts.', 'Open');

INSERT INTO freelance_contracts (id, freelancer_id, client_name, project_title, total_amount, platform_fee_pct, platform_fee_amount, net_earnings, status, deadline)
VALUES ('77777777-7777-7777-7777-777777777701', '11111111-1111-1111-1111-111111111101', 'BatikCraft Store',
 'E-Commerce App UI Overhaul', 2000000, 5, 100000, 1900000, 'Active Work', '2026-09-25');

INSERT INTO freelance_contract_milestones (contract_id, milestone_label, is_completed, sort_order) VALUES
('77777777-7777-7777-7777-777777777701', '1 of 2: Main Home & Product Detail Screen', FALSE, 1),
('77777777-7777-7777-7777-777777777701', '2 of 2: Settings & Transaction History Screen', FALSE, 2);

INSERT INTO community_posts (id, author_id, category, title, content, image_url) VALUES
('88888888-8888-8888-8888-888888888801', '11111111-1111-1111-1111-111111111101', 'Design',
 'How I boosted my UI design workflow efficiency by 3x using Figma Tokens & Variables!',
 'Hey careerroom community! I just published a breakdown of how setting up semantic design tokens early saved our team over 40+ hours during a major app rebranding. Check out the screenshots below!',
 'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?w=700&auto=format&fit=crop&q=80');

INSERT INTO weekly_challenges (id, title, theme, reward_text, deadline_at, description) VALUES
('99999999-9999-9999-9999-999999999901', 'Weekly Design Challenge #42', 'Design a Mobile Banking Dashboard',
 '500 careerroom XP + Verified Challenge Badge', now() + INTERVAL '3 day',
 'Create a modern, dark glassmorphism financial card interface with warm orange accents and cool blue charts.');

INSERT INTO notifications (user_id, type, title, message, is_unread) VALUES
('11111111-1111-1111-1111-111111111101', 'job', 'New Job Match (87%)', 'TechNova Solutions posted Junior UI/UX Designer', TRUE),
('11111111-1111-1111-1111-111111111101', 'mentor', 'Mentor Session Confirmed', 'Dr. Maya Lin confirmed your booking for Today at 15:00', TRUE),
('11111111-1111-1111-1111-111111111101', 'academy', 'Certificate Unlocked!', 'Congratulations! You earned UI/UX Foundations Masterclass Certificate', FALSE);

INSERT INTO admin_metrics_snapshot (total_users, active_users_monthly, total_revenue, course_sales, mentor_bookings_count, job_applications_count, freelance_transactions_count, pro_subscribers, career_plus_subscribers, platform_fee_revenue)
VALUES (14250, 9840, 284500000, 1240, 680, 4320, 310, 1850, 620, 14200000);

COMMIT;
