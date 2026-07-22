-- Migration: Storage bucket RLS policies for chat_images, verification_docs, voice_messages
--
-- Uses PL/pgSQL DO blocks so the migration is idempotent — policies are
-- only created if they don't already exist. This allows the migration to
-- be applied via `supabase db push` even when policies were previously
-- created manually or by another process.

DO $$
BEGIN
  -- ─── chat_images (public read, auth upload, owner manage) ───

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'chat_images_select_public'
  ) THEN
    CREATE POLICY "chat_images_select_public"
      ON storage.objects FOR SELECT
      USING (bucket_id = 'chat_images');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'chat_images_insert_auth'
  ) THEN
    CREATE POLICY "chat_images_insert_auth"
      ON storage.objects FOR INSERT
      WITH CHECK (
          bucket_id = 'chat_images'
          AND auth.role() = 'authenticated'
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'chat_images_update_owner'
  ) THEN
    CREATE POLICY "chat_images_update_owner"
      ON storage.objects FOR UPDATE
      USING (
          bucket_id = 'chat_images'
          AND owner = auth.uid()
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'chat_images_delete_owner'
  ) THEN
    CREATE POLICY "chat_images_delete_owner"
      ON storage.objects FOR DELETE
      USING (
          bucket_id = 'chat_images'
          AND owner = auth.uid()
      );
  END IF;

  -- ─── verification_docs (private — owner only) ───

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'verification_docs_select_owner'
  ) THEN
    CREATE POLICY "verification_docs_select_owner"
      ON storage.objects FOR SELECT
      USING (
          bucket_id = 'verification_docs'
          AND owner = auth.uid()
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'verification_docs_insert_auth'
  ) THEN
    CREATE POLICY "verification_docs_insert_auth"
      ON storage.objects FOR INSERT
      WITH CHECK (
          bucket_id = 'verification_docs'
          AND auth.role() = 'authenticated'
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'verification_docs_update_owner'
  ) THEN
    CREATE POLICY "verification_docs_update_owner"
      ON storage.objects FOR UPDATE
      USING (
          bucket_id = 'verification_docs'
          AND owner = auth.uid()
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'verification_docs_delete_owner'
  ) THEN
    CREATE POLICY "verification_docs_delete_owner"
      ON storage.objects FOR DELETE
      USING (
          bucket_id = 'verification_docs'
          AND owner = auth.uid()
      );
  END IF;

  -- ─── voice_messages (public read, auth upload, owner manage) ───

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'voice_messages_select_public'
  ) THEN
    CREATE POLICY "voice_messages_select_public"
      ON storage.objects FOR SELECT
      USING (bucket_id = 'voice_messages');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'voice_messages_insert_auth'
  ) THEN
    CREATE POLICY "voice_messages_insert_auth"
      ON storage.objects FOR INSERT
      WITH CHECK (
          bucket_id = 'voice_messages'
          AND auth.role() = 'authenticated'
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'voice_messages_update_owner'
  ) THEN
    CREATE POLICY "voice_messages_update_owner"
      ON storage.objects FOR UPDATE
      USING (
          bucket_id = 'voice_messages'
          AND owner = auth.uid()
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND policyname = 'voice_messages_delete_owner'
  ) THEN
    CREATE POLICY "voice_messages_delete_owner"
      ON storage.objects FOR DELETE
      USING (
          bucket_id = 'voice_messages'
          AND owner = auth.uid()
      );
  END IF;
END;
$$;
