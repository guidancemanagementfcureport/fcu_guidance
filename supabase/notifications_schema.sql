-- ============================================
-- NOTIFICATIONS SCHEMA
-- ============================================

-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL, -- 'new_report', 'report_update', 'counseling_chat', etc.
    data JSONB DEFAULT '{}'::jsonb, -- Store IDs like report_id
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- Enable RLS (if needed, but following current patterns)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Simple policies
CREATE POLICY "Users can view their own notifications" 
ON public.notifications FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications" 
ON public.notifications FOR UPDATE 
USING (auth.uid() = user_id);

-- ============================================
-- TRIGGER FOR NEW REPORTS
-- ============================================

-- Function to notify teachers when a new report is submitted
CREATE OR REPLACE FUNCTION public.notify_teachers_new_report()
RETURNS TRIGGER AS $$
DECLARE
    teacher_record RECORD;
BEGIN
    -- Only notify on initial submission
    IF (TG_OP = 'INSERT') THEN
        -- Find all active teachers
        -- Note: In a real app, you might want to filter by department or level
        FOR teacher_record IN 
            SELECT id FROM public.users WHERE role = 'teacher' AND status = 'active'
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                teacher_record.id,
                'New Incident Report',
                'A new report "' || NEW.title || '" has been submitted for review.',
                'new_report',
                jsonb_build_object('report_id', NEW.id)
            );
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger on reports table
DROP TRIGGER IF EXISTS trigger_notify_teachers_new_report ON public.reports;
CREATE TRIGGER trigger_notify_teachers_new_report
AFTER INSERT ON public.reports
FOR EACH ROW
EXECUTE FUNCTION public.notify_teachers_new_report();

-- ============================================
-- TRIGGER FOR REPORT UPDATES (To Student)
-- ============================================

-- Function to notify students when their report status changes
CREATE OR REPLACE FUNCTION public.notify_student_report_update()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO public.notifications (user_id, title, body, type, data)
        VALUES (
            NEW.student_id,
            'Report Status Updated',
            'Your report "' || NEW.title || '" is now: ' || NEW.status,
            'report_update',
            jsonb_build_object('report_id', NEW.id, 'status', NEW.status)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger on reports table for updates
DROP TRIGGER IF EXISTS trigger_notify_student_report_update ON public.reports;
CREATE TRIGGER trigger_notify_student_report_update
AFTER UPDATE OF status ON public.reports
FOR EACH ROW
EXECUTE FUNCTION public.notify_student_report_update();

-- ============================================
-- TRIGGER FOR ANONYMOUS REPORTS
-- ============================================

-- Function to notify teachers when they are assigned to an anonymous report
CREATE OR REPLACE FUNCTION public.notify_teacher_assigned_anonymous_report()
RETURNS TRIGGER AS $$
DECLARE
    report_title TEXT;
BEGIN
    SELECT category INTO report_title FROM public.anonymous_reports WHERE id = NEW.report_id;
    
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (
        NEW.teacher_id,
        'Anonymous Report Assigned',
        'You have been assigned to a new anonymous report: "' || report_title || '".',
        'new_report',
        jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger on anonymous_report_teachers table
DROP TRIGGER IF EXISTS trigger_notify_teacher_assigned_anonymous_report ON public.anonymous_report_teachers;
CREATE TRIGGER trigger_notify_teacher_assigned_anonymous_report
AFTER INSERT ON public.anonymous_report_teachers
FOR EACH ROW
EXECUTE FUNCTION public.notify_teacher_assigned_anonymous_report();

-- ============================================
-- TRIGGER FOR ANONYMOUS MESSAGES
-- ============================================

-- Function to notify the other party (teacher/counselor) when a message is sent in a regular case
CREATE OR REPLACE FUNCTION public.notify_recipient_case_message()
RETURNS TRIGGER AS $$
DECLARE
    report_record RECORD;
    recipient_id UUID;
    recipient_title TEXT;
    dean_loop_record RECORD;
BEGIN
    -- Get the report to find participants
    SELECT title, teacher_id, counselor_id, dean_id INTO report_record 
    FROM public.reports 
    WHERE id = NEW.case_id;

    -- Notify counselor if teacher/dean/admin sends it
    IF (NEW.sender_role IN ('teacher', 'dean', 'admin')) THEN
        recipient_id := report_record.counselor_id;
        IF (recipient_id IS NOT NULL AND recipient_id != NEW.sender_id) THEN
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (recipient_id, 'New Message (' || NEW.sender_role || ')', 'You have received a new message regarding "' || report_record.title || '".', 'new_message', jsonb_build_object('report_id', NEW.case_id, 'is_anonymous', false, 'route', '/counselor/communication'));
        END IF;
    END IF;

    -- Notify teacher if counselor/dean/admin sends it
    IF (NEW.sender_role IN ('counselor', 'dean', 'admin')) THEN
        recipient_id := report_record.teacher_id;
        IF (recipient_id IS NOT NULL AND recipient_id != NEW.sender_id) THEN
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (recipient_id, 'New Message (' || NEW.sender_role || ')', 'You have received a new message regarding "' || report_record.title || '".', 'new_message', jsonb_build_object('report_id', NEW.case_id, 'is_anonymous', false, 'route', '/teacher/communication'));
        END IF;
    END IF;

    -- Notify dean if teacher/counselor/admin sends it
    IF (NEW.sender_role IN ('teacher', 'counselor', 'admin')) THEN
        recipient_id := report_record.dean_id;
        IF (recipient_id IS NOT NULL AND recipient_id != NEW.sender_id) THEN
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (recipient_id, 'New Message (' || NEW.sender_role || ')', 'You have received a new message regarding "' || report_record.title || '".', 'new_message', jsonb_build_object('report_id', NEW.case_id, 'is_anonymous', false, 'route', '/dean/communication'));
        ELSIF (recipient_id IS NULL) THEN
            -- Notify all active deans if no dean is assigned
            FOR dean_loop_record IN SELECT id FROM public.users WHERE role = 'dean' AND status = 'active'
            LOOP
                IF (dean_loop_record.id != NEW.sender_id) THEN
                    INSERT INTO public.notifications (user_id, title, body, type, data)
                    VALUES (dean_loop_record.id, 'New Message (' || NEW.sender_role || ')', 'You have received a new message regarding "' || report_record.title || '".', 'new_message', jsonb_build_object('report_id', NEW.case_id, 'is_anonymous', false, 'route', '/dean/communication'));
                END IF;
            END LOOP;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger on case_messages table
DROP TRIGGER IF EXISTS trigger_notify_recipient_case_message ON public.case_messages;
CREATE TRIGGER trigger_notify_recipient_case_message
AFTER INSERT ON public.case_messages
FOR EACH ROW
EXECUTE FUNCTION public.notify_recipient_case_message();

-- Update function to notify both teachers AND counselors when an anonymous user sends a message
-- AND also notify other participants when a teacher sends a message
CREATE OR REPLACE FUNCTION public.notify_participants_anonymous_message()
RETURNS TRIGGER AS $$
DECLARE
    report_record RECORD;
    teacher_record RECORD;
BEGIN
    -- Get report info
    SELECT category, counselor_id INTO report_record 
    FROM public.anonymous_reports 
    WHERE id = NEW.report_id;

    -- 1. If anonymous user sends a message
    IF (NEW.sender_type = 'anonymous') THEN
        -- Notify all assigned teachers
        FOR teacher_record IN 
            SELECT teacher_id FROM public.anonymous_report_teachers WHERE report_id = NEW.report_id
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                teacher_record.teacher_id,
                'New Anonymous Message',
                'A new message from an anonymous user in "' || report_record.category || '".',
                'new_message', 
                jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true)
            );
        END LOOP;

        -- Notify counselor if assigned
        IF (report_record.counselor_id IS NOT NULL) THEN
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                report_record.counselor_id,
                'New Anonymous Message',
                'A new message from an anonymous user in "' || report_record.category || '".',
                'new_message', 
                jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true)
            );
        END IF;

    -- 2. If a non-anonymous user (teacher/counselor/dean/admin) sends a message
    ELSE
        -- Notify all assigned teachers (excluding sender)
        FOR teacher_record IN 
            SELECT teacher_id FROM public.anonymous_report_teachers 
            WHERE report_id = NEW.report_id AND teacher_id != NEW.sender_id
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                teacher_record.teacher_id,
                'New Message (' || NEW.sender_type || ')',
                'A ' || NEW.sender_type || ' sent a message in anonymous report "' || report_record.category || '".',
                'new_message', 
                jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true, 'route', '/teacher/communication')
            );
        END LOOP;

        -- Notify counselor if assigned and not the sender
        IF (report_record.counselor_id IS NOT NULL AND report_record.counselor_id != NEW.sender_id) THEN
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                report_record.counselor_id,
                'New Message (' || NEW.sender_type || ')',
                'A ' || NEW.sender_type || ' sent a message in anonymous report "' || report_record.category || '".',
                'new_message', 
                jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true, 'route', '/counselor/communication')
            );
        END IF;

        -- Note: Dean/Admin don't have a specific column in anonymous_reports yet, 
        -- but if they are added, we could notify them here too.
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Replace old trigger on anonymous_messages
DROP TRIGGER IF EXISTS trigger_notify_teacher_anonymous_message ON public.anonymous_messages;
DROP TRIGGER IF EXISTS trigger_notify_participants_anonymous_message ON public.anonymous_messages;
CREATE TRIGGER trigger_notify_participants_anonymous_message
AFTER INSERT ON public.anonymous_messages
FOR EACH ROW
EXECUTE FUNCTION public.notify_participants_anonymous_message();
-- ============================================
-- TRIGGER FOR FORWARDED REPORTS (To Counselor)
-- ============================================

-- Function to notify counselor when a report is forwarded to them
CREATE OR REPLACE FUNCTION public.notify_counselor_report_forwarded()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify when status changes to 'forwarded' and counselor_id is set
    IF (NEW.status = 'forwarded' AND (OLD.status IS DISTINCT FROM NEW.status) AND NEW.counselor_id IS NOT NULL) THEN
        INSERT INTO public.notifications (user_id, title, body, type, data)
        VALUES (
            NEW.counselor_id,
            'New Forwarded Report',
            'A new report "' || NEW.title || '" has been forwarded to you for review.',
            'new_report',
            jsonb_build_object('report_id', NEW.id, 'status', NEW.status)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger on reports table for updates
DROP TRIGGER IF EXISTS trigger_notify_counselor_report_forwarded ON public.reports;
CREATE TRIGGER trigger_notify_counselor_report_forwarded
AFTER UPDATE OF status ON public.reports
FOR EACH ROW
EXECUTE FUNCTION public.notify_counselor_report_forwarded();

-- Function to notify counselor when an anonymous report is forwarded to them
CREATE OR REPLACE FUNCTION public.notify_counselor_anonymous_report_forwarded()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify when status changes to 'forwarded' and counselor_id is set
    IF (NEW.status = 'forwarded' AND (OLD.status IS DISTINCT FROM NEW.status) AND NEW.counselor_id IS NOT NULL) THEN
        INSERT INTO public.notifications (user_id, title, body, type, data)
        VALUES (
            NEW.counselor_id,
            'New Forwarded Anonymous Report',
            'A new anonymous report "' || NEW.category || '" has been forwarded to you for review.',
            'new_report',
            jsonb_build_object('report_id', NEW.id, 'status', NEW.status, 'is_anonymous', true)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger on anonymous_reports table for updates
DROP TRIGGER IF EXISTS trigger_notify_counselor_anonymous_report_forwarded ON public.anonymous_reports;
CREATE TRIGGER trigger_notify_counselor_anonymous_report_forwarded
AFTER UPDATE OF status ON public.anonymous_reports
FOR EACH ROW
EXECUTE FUNCTION public.notify_counselor_anonymous_report_forwarded();

-- ============================================
-- TRIGGER FOR REVIEWED REPORTS (To Dean)
-- ============================================

-- Function to notify dean when a report is reviewed by counselor
CREATE OR REPLACE FUNCTION public.notify_dean_report_reviewed()
RETURNS TRIGGER AS $$
DECLARE
    dean_record RECORD;
BEGIN
    -- Notify when status changes to 'counselor_reviewed'
    IF (NEW.status = 'counselor_reviewed' AND (OLD.status IS DISTINCT FROM NEW.status)) THEN
        -- Notify all active deans
        FOR dean_record IN 
            SELECT id FROM public.users WHERE role = 'dean' AND status = 'active'
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                dean_record.id,
                'New Report for Approval',
                'A counselor has reviewed "' || NEW.title || '" and it is now pending your approval.',
                'new_report',
                jsonb_build_object('report_id', NEW.id, 'status', NEW.status, 'route', '/dean/reports')
            );
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger on reports table for Dean notification
DROP TRIGGER IF EXISTS trigger_notify_dean_report_reviewed ON public.reports;
CREATE TRIGGER trigger_notify_dean_report_reviewed
AFTER UPDATE OF status ON public.reports
FOR EACH ROW
EXECUTE FUNCTION public.notify_dean_report_reviewed();

-- Function to notify dean when an anonymous report is forwarded to them
-- (Assuming anonymous reports also use 'counselor_reviewed' or similar at some point,
-- or if 'forwarded' in anonymous_reports also target deans if counselor_id is null? 
-- But based on counselor_reports page, they usually go to counselor first)

CREATE OR REPLACE FUNCTION public.notify_dean_anonymous_report_reviewed()
RETURNS TRIGGER AS $$
DECLARE
    dean_record RECORD;
BEGIN
    -- If counselor reviewed an anonymous case (if we use same status pattern)
    IF (NEW.status = 'counselor_reviewed' AND (OLD.status IS DISTINCT FROM NEW.status)) THEN
        FOR dean_record IN 
            SELECT id FROM public.users WHERE role = 'dean' AND status = 'active'
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                dean_record.id,
                'Anonymous Case Approval',
                'An anonymous report "' || NEW.category || '" has been reviewed and needs your approval.',
                'new_report',
                jsonb_build_object('report_id', NEW.id, 'status', NEW.status, 'is_anonymous', true, 'route', '/dean/reports')
            );
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger on anonymous_reports
DROP TRIGGER IF EXISTS trigger_notify_dean_anonymous_report_reviewed ON public.anonymous_reports;
CREATE TRIGGER trigger_notify_dean_anonymous_report_reviewed
AFTER UPDATE OF status ON public.anonymous_reports
FOR EACH ROW
EXECUTE FUNCTION public.notify_dean_anonymous_report_reviewed();
