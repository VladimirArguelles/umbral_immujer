---
name: supabase-rls-architect
description: Designs, implements, and audits Supabase and PostgreSQL Row Level Security (RLS) policies, multi-tenant isolation, role-based access control (RBAC), security definer helper functions, and safe database triggers. Use when protecting database tables, reviewing data leaks, adding user permissions, or locking down public APIs.
---

# Supabase Row Level Security (RLS) Architect

This skill provides patterns, templates, and best practices for creating zero-trust PostgreSQL **Row Level Security (RLS)** architectures in Supabase.

---

## The Zero-Trust Checklist

1. **Every Public Table Must Have RLS Enabled**:
   ```sql
   ALTER TABLE public.table_name ENABLE ROW LEVEL SECURITY;
   ```
2. **Explicit Deny by Default**:
   When RLS is enabled without policies, PostgreSQL rejects all `anon` and `authenticated` queries by default (returning empty sets or errors).
3. **Never Trust Client-Provided Roles**:
   Never trust `role` or `user_id` sent in HTTP request bodies or URL parameters. Always validate against `auth.uid()` or validated JWT claims.
4. **Distinguish Policy Actions**:
   Define distinct policies for `SELECT`, `INSERT`, `UPDATE`, and `DELETE` rather than relying on blanket `FOR ALL` policies, unless identical checks apply.
5. **Optimize Function Execution**:
   Wrap role-checking queries inside `SECURITY DEFINER` functions with fixed search paths (`SET search_path = public`) to prevent infinite recursion in RLS subqueries.

---

## Canonical Multi-Role Architecture Patterns

### 1. Role-Check Helper Functions (Fast & Cached)
```sql
-- Checks if the authenticated user is a Super Admin
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE id = auth.uid() AND rol = 'super_admin'
    );
END;
$$;

-- Checks if the authenticated user is a Coordinator or Admin
CREATE OR REPLACE FUNCTION public.is_coordinador()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE id = auth.uid() AND rol IN ('coordinador', 'super_admin')
    );
END;
$$;
```

---

### 2. Multi-Tier Policy Blueprint

#### Profiles / Users Table (`perfiles`)
```sql
-- Anyone authenticated can read user names/roles
CREATE POLICY "perfiles_select_all"
ON public.perfiles
FOR SELECT
TO authenticated
USING (true);

-- Users can only modify their own profile, or coordinators can manage all
CREATE POLICY "perfiles_update_own_or_admin"
ON public.perfiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id OR is_coordinador())
WITH CHECK (auth.uid() = id OR is_coordinador());
```

#### Student Records (`alumnos`)
```sql
-- Reading student records
CREATE POLICY "alumnos_select_authenticated"
ON public.alumnos
FOR SELECT
TO authenticated
USING (
    is_coordinador()
    OR auth.uid() = user_id
    OR EXISTS (
        -- Teachers can read students enrolled in their courses
        SELECT 1 FROM public.inscripciones i
        JOIN public.cursos c ON c.id = i.curso_id
        WHERE i.alumno_id = public.alumnos.id
          AND c.profesor_id = auth.uid()
    )
);

-- Insertion and updates restricted to coordinators/admins
CREATE POLICY "alumnos_write_coordinators"
ON public.alumnos
FOR INSERT
TO authenticated
WITH CHECK (is_coordinador());

CREATE POLICY "alumnos_update_coordinators"
ON public.alumnos
FOR UPDATE
TO authenticated
USING (is_coordinador() OR auth.uid() = user_id)
WITH CHECK (is_coordinador() OR auth.uid() = user_id);
```

#### Attendance Tracking (`asistencia`)
```sql
-- View attendance: Students see own, teachers see course, coordinators see all
CREATE POLICY "asistencia_select_policy"
ON public.asistencia
FOR SELECT
TO authenticated
USING (
    is_coordinador()
    OR EXISTS (
        SELECT 1 FROM public.alumnos a
        WHERE a.id = public.asistencia.alumno_id AND a.user_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.cursos c
        WHERE c.id = public.asistencia.curso_id AND c.profesor_id = auth.uid()
    )
);

-- Write attendance: Teachers of the course and coordinators
CREATE POLICY "asistencia_write_policy"
ON public.asistencia
FOR INSERT
TO authenticated
WITH CHECK (
    is_coordinador()
    OR EXISTS (
        SELECT 1 FROM public.cursos c
        WHERE c.id = public.asistencia.curso_id AND c.profesor_id = auth.uid()
    )
);
```

---

## Verifying RLS & Security Auditing
To inspect all tables and verify that zero tables are unprotected:
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;
```
Ensure every table returns `rowsecurity = true`.
