-- Migration: Add `metadata` column to `messages` table (2026-07-23)
--
-- The `messages` table was missing a `metadata` column, causing all image
-- and voice message sends to fail with a PostgREST 400 error because the
-- Dart client inserts a `metadata` JSONB field (e.g. {"type":"image","url":"..."}).
--
-- This column stores structured metadata about non-text messages such as
-- image URLs, voice recording URLs, location data, and file attachments.

ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS metadata JSONB;
