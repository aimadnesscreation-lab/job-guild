-- Migration: Add verification document columns to users table
--
-- Needed by the ID verification flow to store uploaded document URLs.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS id_document_url TEXT,
  ADD COLUMN IF NOT EXISTS selfie_url TEXT;
