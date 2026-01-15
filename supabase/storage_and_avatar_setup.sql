-- Storage and User Avatar Setup
-- ================================================

-- 1. Add avatar_url to users table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'avatar_url'
  ) THEN
    ALTER TABLE public.users
    ADD COLUMN avatar_url text;
    RAISE NOTICE 'Added avatar_url column to users table';
  ELSE
    RAISE NOTICE 'avatar_url column already exists';
  END IF;
END $$;

-- 2. Create Storage Bucket 'app_assets'
-- Note: This requires the storage extension to be enabled
INSERT INTO storage.buckets (id, name, public)
SELECT 'app_assets', 'app_assets', true
WHERE NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'app_assets'
);

-- 3. Set up Storage Policies for 'app_assets'
-- Allow public access to view avatars
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Public Access to app_assets'
    ) THEN
        CREATE POLICY "Public Access to app_assets"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'app_assets');
    END IF;
END $$;

-- Allow authenticated users to upload avatars
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can upload avatars'
    ) THEN
        CREATE POLICY "Authenticated users can upload avatars"
        ON storage.objects FOR INSERT
        WITH CHECK (
            bucket_id = 'app_assets' 
            AND auth.role() = 'authenticated'
        );
    END IF;
END $$;

-- Allow users to update their own avatars
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own avatars'
    ) THEN
        CREATE POLICY "Users can update their own avatars"
        ON storage.objects FOR UPDATE
        USING (
            bucket_id = 'app_assets' 
            AND auth.uid()::text = (storage.foldername(name))[1]
        );
    END IF;
END $$;

-- Allow users to delete their own avatars
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their own avatars'
    ) THEN
        CREATE POLICY "Users can delete their own avatars"
        ON storage.objects FOR DELETE
        USING (
            bucket_id = 'app_assets' 
            AND auth.uid()::text = (storage.foldername(name))[1]
        );
    END IF;
END $$;
