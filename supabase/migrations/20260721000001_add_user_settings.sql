-- Migration: Add user settings columns for the Settings screen
--
-- The `users` table already has `preferred_language`. This migration adds the
-- remaining settings fields so the Flutter app can persist them.

-- Notification & service radius preferences
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS job_alerts_enabled BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS message_alerts_enabled BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS service_radius_km INTEGER DEFAULT 10;
