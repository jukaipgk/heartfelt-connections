
CREATE TABLE public.crud_check (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  label text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.crud_check TO anon, authenticated;
GRANT ALL ON public.crud_check TO service_role;

ALTER TABLE public.crud_check ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public read"   ON public.crud_check FOR SELECT USING (true);
CREATE POLICY "public insert" ON public.crud_check FOR INSERT WITH CHECK (true);
CREATE POLICY "public update" ON public.crud_check FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "public delete" ON public.crud_check FOR DELETE USING (true);
