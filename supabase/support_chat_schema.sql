-- ============================================
-- SUPPORT CHAT SCHEMA (AI-Assisted)
-- ============================================

-- Support Sessions
CREATE TABLE IF NOT EXISTS public.support_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.users(id) ON DELETE SET NULL, -- Null if anonymous
    student_name TEXT, -- To store name for display if anonymous or for fast lookup
    category TEXT DEFAULT 'General Support',
    status TEXT NOT NULL DEFAULT 'ai_active', -- 'ai_active', 'human_active', 'resolved'
    is_urgent BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Support Messages
CREATE TABLE IF NOT EXISTS public.support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.support_sessions(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL, -- Null for AI or anonymous student
    sender_role TEXT NOT NULL, -- 'student', 'teacher', 'counselor', 'ai'
    message TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'text', -- 'text', 'ai_assistance'
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for session lookups
CREATE INDEX IF NOT EXISTS idx_support_messages_session_id ON public.support_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_support_sessions_student_id ON public.support_sessions(student_id);

-- Enable RLS
ALTER TABLE public.support_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

-- Simple RLS Policies
CREATE POLICY "Users can view their own support sessions"
ON public.support_sessions FOR SELECT
USING (auth.uid() = student_id OR student_id IS NULL OR EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('teacher', 'counselor', 'dean', 'admin')
));

-- Allow students and anonymous users to create sessions
CREATE POLICY "Anyone can create a support session"
ON public.support_sessions FOR INSERT
WITH CHECK (true);

-- Allow staff to update sessions (status, urgency etc)
CREATE POLICY "Staff can update support sessions"
ON public.support_sessions FOR UPDATE
USING (EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('teacher', 'counselor', 'dean', 'admin')
));

-- Messages: Users see messages for their sessions, Staff see all
CREATE POLICY "Users can view messages for their support sessions"
ON public.support_messages FOR SELECT
USING (EXISTS (
    SELECT 1 FROM public.support_sessions WHERE id = session_id AND (student_id = auth.uid() OR student_id IS NULL OR EXISTS (
        SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('teacher', 'counselor', 'dean', 'admin')
    ))
));

-- Anyone can insert messages to their sessions (verified by session existence)
CREATE POLICY "Anyone can send messages to support sessions"
ON public.support_messages FOR INSERT
WITH CHECK (EXISTS (
    SELECT 1 FROM public.support_sessions WHERE id = session_id
));

-- Staff can insert messages to any session
CREATE POLICY "Staff can reply to any support session"
ON public.support_messages FOR INSERT
WITH CHECK (EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('teacher', 'counselor', 'dean', 'admin')
));

-- Enable real-time for support messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;

-- ============================================
-- TRIGGER FOR SUPPORT CHAT NOTIFICATIONS
-- ============================================

CREATE OR REPLACE FUNCTION public.notify_staff_support_message()
RETURNS TRIGGER AS $$
DECLARE
    session_record RECORD;
    staff_record RECORD;
    sender_name TEXT;
BEGIN
    -- Get session info
    SELECT * INTO session_record FROM public.support_sessions WHERE id = NEW.session_id;
    
    -- Only notify if sender is 'student'
    IF (NEW.sender_role = 'student') THEN
        sender_name := COALESCE(session_record.student_name, 'Anonymous Student');
        
        -- Get all active counselors and teachers
        -- For MVP, notify all counselors and potentially teachers
        FOR staff_record IN 
            SELECT id FROM public.users WHERE role IN ('counselor', 'teacher') AND status = 'active'
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                staff_record.id,
                'New Support Chat Message',
                sender_name || ' is asking for assistance. AI is currently responding.',
                'new_message',
                jsonb_build_object(
                    'report_id', NEW.session_id, 
                    'is_support', true,
                    'route', '/counselor/communication' -- Staff can check in communication tools
                )
            );
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_notify_staff_support_message ON public.support_messages;
CREATE TRIGGER trigger_notify_staff_support_message
AFTER INSERT ON public.support_messages
FOR EACH ROW
EXECUTE FUNCTION public.notify_staff_support_message();
