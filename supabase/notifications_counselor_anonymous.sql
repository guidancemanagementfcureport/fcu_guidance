-- ============================================
-- NOTIFICATIONS FOR COUNSELOR ASSIGNED ANONYMOUS REPORTS
-- ============================================

-- Function to notify counselors when they are assigned to an anonymous report
CREATE OR REPLACE FUNCTION public.notify_counselor_assigned_anonymous_report()
RETURNS TRIGGER AS $$
DECLARE
    report_title TEXT;
BEGIN
    SELECT category INTO report_title FROM public.anonymous_reports WHERE id = NEW.report_id;
    
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (
        NEW.counselor_id,
        'Anonymous Report Assigned',
        'You have been assigned to a new anonymous report: "' || report_title || '".',
        'new_report',
        jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger on anonymous_report_counselors table
DROP TRIGGER IF EXISTS trigger_notify_counselor_assigned_anonymous_report ON public.anonymous_report_counselors;
CREATE TRIGGER trigger_notify_counselor_assigned_anonymous_report
AFTER INSERT ON public.anonymous_report_counselors
FOR EACH ROW
EXECUTE FUNCTION public.notify_counselor_assigned_anonymous_report();

-- ============================================
-- UPDATE MESSAGE NOTIFICATIONS TO CHECK ANONYMOUS COUNSELORS
-- ============================================

CREATE OR REPLACE FUNCTION public.notify_participants_anonymous_message()
RETURNS TRIGGER AS $$
DECLARE
    report_record RECORD;
    teacher_record RECORD;
    counselor_record RECORD;
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

        -- Notify all assigned counselors (NEW LOGIC)
        FOR counselor_record IN 
            SELECT counselor_id FROM public.anonymous_report_counselors WHERE report_id = NEW.report_id
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                counselor_record.counselor_id,
                'New Anonymous Message',
                'A new message from an anonymous user in "' || report_record.category || '".',
                'new_message', 
                jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true)
            );
        END LOOP;
        
        -- Fallback: Notify counselor if assigned in main table but not in join table (legacy)
        IF (report_record.counselor_id IS NOT NULL) THEN
            -- Check if not already notified via loop to avoid duplicates
            IF NOT EXISTS (SELECT 1 FROM public.anonymous_report_counselors WHERE report_id = NEW.report_id AND counselor_id = report_record.counselor_id) THEN
                INSERT INTO public.notifications (user_id, title, body, type, data)
                VALUES (
                    report_record.counselor_id,
                    'New Anonymous Message',
                    'A new message from an anonymous user in "' || report_record.category || '".',
                    'new_message', 
                    jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true)
                );
            END IF;
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

        -- Notify all assigned counselors (excluding sender) (NEW LOGIC)
        FOR counselor_record IN 
            SELECT counselor_id FROM public.anonymous_report_counselors 
            WHERE report_id = NEW.report_id AND counselor_id != NEW.sender_id
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                counselor_record.counselor_id,
                'New Message (' || NEW.sender_type || ')',
                'A ' || NEW.sender_type || ' sent a message in anonymous report "' || report_record.category || '".',
                'new_message', 
                jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true, 'route', '/counselor/communication')
            );
        END LOOP;

        -- Fallback: Notify counselor if assigned in main table and not sender (legacy)
        IF (report_record.counselor_id IS NOT NULL AND report_record.counselor_id != NEW.sender_id) THEN
             IF NOT EXISTS (SELECT 1 FROM public.anonymous_report_counselors WHERE report_id = NEW.report_id AND counselor_id = report_record.counselor_id) THEN
                INSERT INTO public.notifications (user_id, title, body, type, data)
                VALUES (
                    report_record.counselor_id,
                    'New Message (' || NEW.sender_type || ')',
                    'A ' || NEW.sender_type || ' sent a message in anonymous report "' || report_record.category || '".',
                    'new_message', 
                    jsonb_build_object('report_id', NEW.report_id, 'is_anonymous', true, 'route', '/counselor/communication')
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
