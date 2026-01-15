-- ============================================
-- NOTIFICATIONS FOR STUDENT HISTORY (COUNSELING REQUESTS)
-- ============================================

-- 1. NOTIFY COUNSELORS OF NEW COUNSELING REQUESTS
-- Triggered when a student (or system) creates a new counseling request
CREATE OR REPLACE FUNCTION public.notify_new_counseling_request()
RETURNS TRIGGER AS $$
DECLARE
    student_name TEXT;
    counselor_record RECORD;
BEGIN
    -- Get student name for the notification body
    SELECT full_name INTO student_name FROM public.users WHERE id = NEW.student_id;
    IF student_name IS NULL THEN
        student_name := 'A student';
    END IF;

    -- If a specific counselor is assigned, notify them
    IF (NEW.counselor_id IS NOT NULL) THEN
        INSERT INTO public.notifications (user_id, title, body, type, data)
        VALUES (
            NEW.counselor_id,
            'New Counseling Request',
            student_name || ' has requested a counseling session.',
            'new_counseling_request',
            jsonb_build_object('request_id', NEW.id, 'role', 'counselor')
        );
    ELSE
        -- If no specific counselor assigned, notify ALL active counselors
        FOR counselor_record IN 
            SELECT id FROM public.users WHERE role = 'counselor' AND status = 'active'
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, data)
            VALUES (
                counselor_record.id,
                'New Counseling Request',
                student_name || ' has requested a counseling session.',
                'new_counseling_request',
                jsonb_build_object('request_id', NEW.id, 'role', 'counselor')
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_notify_new_counseling_request ON public.counseling_requests;
CREATE TRIGGER trigger_notify_new_counseling_request
AFTER INSERT ON public.counseling_requests
FOR EACH ROW
EXECUTE FUNCTION public.notify_new_counseling_request();

-- 2. NOTIFY STUDENT OF REQUEST STATUS UPDATES
-- Triggered when the status of a counseling request changes
CREATE OR REPLACE FUNCTION public.notify_student_counseling_update()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO public.notifications (user_id, title, body, type, data)
        VALUES (
            NEW.student_id,
            'Counseling Request Updated',
            'Your counseling request status has been updated to: ' || NEW.status,
            'counseling_update',
            jsonb_build_object('request_id', NEW.id, 'status', NEW.status, 'role', 'student')
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_notify_student_counseling_update ON public.counseling_requests;
CREATE TRIGGER trigger_notify_student_counseling_update
AFTER UPDATE OF status ON public.counseling_requests
FOR EACH ROW
EXECUTE FUNCTION public.notify_student_counseling_update();
