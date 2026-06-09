
-- ============== ENUMS ==============
CREATE TYPE public.gender AS ENUM ('L','P');
CREATE TYPE public.religion AS ENUM ('ISLAM','KRISTEN','KATOLIK','HINDU','BUDDHA','KONGHUCU','LAINNYA');
CREATE TYPE public.parent_relation AS ENUM ('AYAH','IBU','WALI');
CREATE TYPE public.attendance_status AS ENUM ('HADIR','SAKIT','IZIN','ALPA','TERLAMBAT');
CREATE TYPE public.assessment_type AS ENUM ('TUGAS','ULANGAN_HARIAN','UTS','UAS','PRAKTIK','PROYEK','SIKAP');
CREATE TYPE public.employment_type AS ENUM ('PNS','PPPK','TETAP_YAYASAN','HONORER','KONTRAK','MAGANG');
CREATE TYPE public.student_status AS ENUM ('AKTIF','LULUS','PINDAH','KELUAR','CUTI');
CREATE TYPE public.subject_group AS ENUM ('UMUM','AGAMA','BAHASA','MATEMATIKA','IPA','IPS','SENI','OLAHRAGA','KEJURUAN','MUATAN_LOKAL');

-- ============== HELPER ==============
CREATE OR REPLACE FUNCTION public.user_can_access_school(_uid uuid, _school_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.is_superadmin(_uid)
    OR EXISTS (SELECT 1 FROM public.user_roles ur
               JOIN public.schools s ON s.id = _school_id
               WHERE ur.user_id = _uid
                 AND ur.role = 'FOUNDATION_ADMIN'
                 AND (ur.foundation_id IS NULL OR ur.foundation_id = s.foundation_id))
    OR EXISTS (SELECT 1 FROM public.user_school_access usa
               WHERE usa.user_id = _uid AND usa.school_id = _school_id)
    OR EXISTS (SELECT 1 FROM public.user_roles ur
               WHERE ur.user_id = _uid AND ur.school_id = _school_id);
$$;

-- ============== ACADEMIC YEARS / TERMS ==============
CREATE TABLE public.academic_years (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  name text NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  is_active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(school_id, name)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.academic_years TO authenticated;
GRANT ALL ON public.academic_years TO service_role;
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;
CREATE POLICY ay_all ON public.academic_years FOR ALL TO authenticated
  USING (public.user_can_access_school(auth.uid(), school_id))
  WITH CHECK (public.user_can_access_school(auth.uid(), school_id));
CREATE TRIGGER trg_ay_updated BEFORE UPDATE ON public.academic_years FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.academic_terms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE CASCADE,
  name text NOT NULL,
  ordinal int NOT NULL DEFAULT 1,
  start_date date NOT NULL,
  end_date date NOT NULL,
  is_active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(academic_year_id, ordinal)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.academic_terms TO authenticated;
GRANT ALL ON public.academic_terms TO service_role;
ALTER TABLE public.academic_terms ENABLE ROW LEVEL SECURITY;
CREATE POLICY at_all ON public.academic_terms FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.academic_years ay
                 WHERE ay.id = academic_year_id AND public.user_can_access_school(auth.uid(), ay.school_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.academic_years ay
                 WHERE ay.id = academic_year_id AND public.user_can_access_school(auth.uid(), ay.school_id)));
CREATE TRIGGER trg_at_updated BEFORE UPDATE ON public.academic_terms FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== SUBJECTS ==============
CREATE TABLE public.subjects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL,
  subject_group public.subject_group NOT NULL DEFAULT 'UMUM',
  kkm int NOT NULL DEFAULT 70,
  description text,
  status public.entity_status NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(school_id, code)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.subjects TO authenticated;
GRANT ALL ON public.subjects TO service_role;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
CREATE POLICY subj_all ON public.subjects FOR ALL TO authenticated
  USING (public.user_can_access_school(auth.uid(), school_id))
  WITH CHECK (public.user_can_access_school(auth.uid(), school_id));
CREATE TRIGGER trg_subj_updated BEFORE UPDATE ON public.subjects FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== STAFF (teachers/employees) ==============
CREATE TABLE public.staff (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  nip text,
  full_name text NOT NULL,
  gender public.gender,
  birth_place text,
  birth_date date,
  email text,
  phone text,
  address text,
  employment_type public.employment_type NOT NULL DEFAULT 'TETAP_YAYASAN',
  position text,
  is_teacher boolean NOT NULL DEFAULT true,
  joined_at date,
  status public.entity_status NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(school_id, nip)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.staff TO authenticated;
GRANT ALL ON public.staff TO service_role;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
CREATE POLICY staff_all ON public.staff FOR ALL TO authenticated
  USING (public.user_can_access_school(auth.uid(), school_id))
  WITH CHECK (public.user_can_access_school(auth.uid(), school_id));
CREATE TRIGGER trg_staff_updated BEFORE UPDATE ON public.staff FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== CLASSES (Rombel) ==============
CREATE TABLE public.classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE CASCADE,
  grade_level int NOT NULL,
  name text NOT NULL,
  homeroom_teacher_id uuid REFERENCES public.staff(id) ON DELETE SET NULL,
  capacity int NOT NULL DEFAULT 32,
  room text,
  status public.entity_status NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(academic_year_id, name)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.classes TO authenticated;
GRANT ALL ON public.classes TO service_role;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
CREATE POLICY cl_all ON public.classes FOR ALL TO authenticated
  USING (public.user_can_access_school(auth.uid(), school_id))
  WITH CHECK (public.user_can_access_school(auth.uid(), school_id));
CREATE TRIGGER trg_cl_updated BEFORE UPDATE ON public.classes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== CLASS SUBJECTS ==============
CREATE TABLE public.class_subjects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  teacher_id uuid REFERENCES public.staff(id) ON DELETE SET NULL,
  weekly_hours int NOT NULL DEFAULT 2,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(class_id, subject_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.class_subjects TO authenticated;
GRANT ALL ON public.class_subjects TO service_role;
ALTER TABLE public.class_subjects ENABLE ROW LEVEL SECURITY;
CREATE POLICY cs_all ON public.class_subjects FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.classes c WHERE c.id = class_id AND public.user_can_access_school(auth.uid(), c.school_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.classes c WHERE c.id = class_id AND public.user_can_access_school(auth.uid(), c.school_id)));
CREATE TRIGGER trg_cs_updated BEFORE UPDATE ON public.class_subjects FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== SCHEDULES ==============
CREATE TABLE public.schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_subject_id uuid NOT NULL REFERENCES public.class_subjects(id) ON DELETE CASCADE,
  day_of_week int NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time time NOT NULL,
  end_time time NOT NULL,
  room text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.schedules TO authenticated;
GRANT ALL ON public.schedules TO service_role;
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
CREATE POLICY sch_all ON public.schedules FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.class_subjects cs JOIN public.classes c ON c.id = cs.class_id
                 WHERE cs.id = class_subject_id AND public.user_can_access_school(auth.uid(), c.school_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.class_subjects cs JOIN public.classes c ON c.id = cs.class_id
                 WHERE cs.id = class_subject_id AND public.user_can_access_school(auth.uid(), c.school_id)));
CREATE TRIGGER trg_sch_updated BEFORE UPDATE ON public.schedules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== STUDENTS ==============
CREATE TABLE public.students (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  foundation_id uuid NOT NULL REFERENCES public.foundations(id) ON DELETE CASCADE,
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  nisn text,
  nis text,
  full_name text NOT NULL,
  nick_name text,
  gender public.gender NOT NULL DEFAULT 'L',
  birth_place text,
  birth_date date,
  religion public.religion DEFAULT 'ISLAM',
  address text,
  city text,
  province text,
  postal_code text,
  phone text,
  email text,
  photo_url text,
  enrollment_date date DEFAULT CURRENT_DATE,
  status public.student_status NOT NULL DEFAULT 'AKTIF',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(school_id, nisn),
  UNIQUE(school_id, nis)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.students TO authenticated;
GRANT ALL ON public.students TO service_role;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
CREATE POLICY st_all ON public.students FOR ALL TO authenticated
  USING (public.user_can_access_school(auth.uid(), school_id))
  WITH CHECK (public.user_can_access_school(auth.uid(), school_id));
CREATE TRIGGER trg_st_updated BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== STUDENT PARENTS ==============
CREATE TABLE public.student_parents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  relation public.parent_relation NOT NULL DEFAULT 'AYAH',
  full_name text NOT NULL,
  nik text,
  occupation text,
  phone text,
  email text,
  address text,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.student_parents TO authenticated;
GRANT ALL ON public.student_parents TO service_role;
ALTER TABLE public.student_parents ENABLE ROW LEVEL SECURITY;
CREATE POLICY sp_all ON public.student_parents FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.students s WHERE s.id = student_id AND public.user_can_access_school(auth.uid(), s.school_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.students s WHERE s.id = student_id AND public.user_can_access_school(auth.uid(), s.school_id)));
CREATE TRIGGER trg_sp_updated BEFORE UPDATE ON public.student_parents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== STUDENT ENROLLMENTS (per class per year) ==============
CREATE TABLE public.student_enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE CASCADE,
  roll_number int,
  status public.student_status NOT NULL DEFAULT 'AKTIF',
  enrolled_at date NOT NULL DEFAULT CURRENT_DATE,
  exited_at date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(student_id, academic_year_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.student_enrollments TO authenticated;
GRANT ALL ON public.student_enrollments TO service_role;
ALTER TABLE public.student_enrollments ENABLE ROW LEVEL SECURITY;
CREATE POLICY se_all ON public.student_enrollments FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.students s WHERE s.id = student_id AND public.user_can_access_school(auth.uid(), s.school_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.students s WHERE s.id = student_id AND public.user_can_access_school(auth.uid(), s.school_id)));
CREATE TRIGGER trg_se_updated BEFORE UPDATE ON public.student_enrollments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== ATTENDANCE ==============
CREATE TABLE public.attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  attendance_date date NOT NULL,
  status public.attendance_status NOT NULL DEFAULT 'HADIR',
  note text,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(class_id, student_id, attendance_date)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.attendance TO authenticated;
GRANT ALL ON public.attendance TO service_role;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
CREATE POLICY att_all ON public.attendance FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.classes c WHERE c.id = class_id AND public.user_can_access_school(auth.uid(), c.school_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.classes c WHERE c.id = class_id AND public.user_can_access_school(auth.uid(), c.school_id)));
CREATE TRIGGER trg_att_updated BEFORE UPDATE ON public.attendance FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== GRADES ==============
CREATE TABLE public.grades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_subject_id uuid NOT NULL REFERENCES public.class_subjects(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  term_id uuid NOT NULL REFERENCES public.academic_terms(id) ON DELETE CASCADE,
  assessment_type public.assessment_type NOT NULL DEFAULT 'TUGAS',
  title text,
  score numeric(5,2) NOT NULL DEFAULT 0,
  weight numeric(4,2) NOT NULL DEFAULT 1,
  note text,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.grades TO authenticated;
GRANT ALL ON public.grades TO service_role;
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
CREATE POLICY gr_all ON public.grades FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.class_subjects cs JOIN public.classes c ON c.id = cs.class_id
                 WHERE cs.id = class_subject_id AND public.user_can_access_school(auth.uid(), c.school_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.class_subjects cs JOIN public.classes c ON c.id = cs.class_id
                 WHERE cs.id = class_subject_id AND public.user_can_access_school(auth.uid(), c.school_id)));
CREATE TRIGGER trg_gr_updated BEFORE UPDATE ON public.grades FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============== INDEXES ==============
CREATE INDEX idx_students_school ON public.students(school_id);
CREATE INDEX idx_classes_school_year ON public.classes(school_id, academic_year_id);
CREATE INDEX idx_enrollments_class ON public.student_enrollments(class_id);
CREATE INDEX idx_attendance_class_date ON public.attendance(class_id, attendance_date);
CREATE INDEX idx_grades_student_term ON public.grades(student_id, term_id);
CREATE INDEX idx_staff_school ON public.staff(school_id);
CREATE INDEX idx_subjects_school ON public.subjects(school_id);
