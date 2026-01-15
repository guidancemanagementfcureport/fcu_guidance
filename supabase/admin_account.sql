INSERT INTO public.users (
    id,
    gmail,
    full_name,
    role,
    department,
    status,
    created_at
) 
SELECT 
    id,                                    -- Automatically gets UUID from auth.users
    email,                                 -- Automatically gets email from auth.users
    'System Administrator',                -- Your full name
    'admin',                               -- Role must be 'admin'
    'Administration',                      -- Department
    'active',                              -- Status
    NOW()                                  -- Created timestamp
FROM auth.users
WHERE email = 'admin@gmail.com'           -- ⚠️ CHANGE THIS to your Gmail address
ON CONFLICT (id) DO NOTHING;