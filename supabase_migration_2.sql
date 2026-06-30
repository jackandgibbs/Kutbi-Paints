-- ============================================================
-- Kutbi Paints — Reward Milestones Migration
-- Run this in your Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS milestones (
    id TEXT PRIMARY KEY,
    target_points INT NOT NULL,
    reward_title TEXT NOT NULL,
    reward_type TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- We need a table to track which painter achieved which milestone so we don't reward them multiple times for the same milestone.
CREATE TABLE IF NOT EXISTS milestone_achievements (
    id TEXT PRIMARY KEY,
    painter_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    milestone_id TEXT REFERENCES milestones(id) ON DELETE CASCADE,
    achieved_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(painter_id, milestone_id)
);

NOTIFY pgrst, 'reload schema';
