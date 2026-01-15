-- Function to allow admins to update user passwords
-- Run this in your Supabase SQL Editor

-- 1. Create the function
create or replace function admin_update_user_password(
  target_user_id uuid,
  new_password text
)
returns void
language plpgsql
security definer
as $$
begin
  -- Check if the calling user is an admin
  -- We check the 'users' table to see if the current auth.uid() has rol = 'admin'
  if not exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Access denied: Only admins can reset passwords.';
  end if;

  -- Update the password in auth.users
  -- Note: We use the pgcrypto extension which is enabled by default in Supabase
  update auth.users
  set encrypted_password = crypt(new_password, gen_salt('bf'))
  where id = target_user_id;
end;
$$;
