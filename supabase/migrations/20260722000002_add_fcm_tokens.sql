-- Migration: Add FCM tokens table and RPC for push notifications
--
-- Stores device FCM tokens per user so the send-push-notification Edge
-- Function can deliver push notifications to the right device(s).

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast token lookup by user
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON public.fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token ON public.fcm_tokens(token);

-- Enable RLS
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Policies: users can manage their own tokens
CREATE POLICY "Users can insert own FCM tokens"
  ON public.fcm_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own FCM tokens"
  ON public.fcm_tokens FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own FCM tokens"
  ON public.fcm_tokens FOR DELETE
  USING (auth.uid() = user_id);

-- Service role can read any token (for Edge Function)
-- This is handled by the service_role key bypassing RLS

-- ─── RPC to get a user's latest FCM token ─────────────────────

CREATE OR REPLACE FUNCTION get_user_fcm_token(p_user_id UUID)
RETURNS TABLE (token TEXT, platform TEXT)
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT ft.token, ft.platform
  FROM fcm_tokens ft
  WHERE ft.user_id = p_user_id
  ORDER BY ft.updated_at DESC
  LIMIT 1;
END;
$$;
