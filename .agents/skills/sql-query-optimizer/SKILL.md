---
name: sql-query-optimizer
description: Analyzes, benchmarks, and optimizes PostgreSQL and Supabase SQL queries, execution plans (EXPLAIN ANALYZE), index design, join patterns, connection overhead, and batching. Use when queries are slow, timeouts occur, missing indexes cause sequential scans, or database throughput needs optimization.
---

# SQL Query Optimizer for PostgreSQL & Supabase

This skill provides methodologies, diagnostic runbooks, and index strategies to eliminate slow queries, prevent table lockups, and keep PostgreSQL latencies under 10ms.

---

## 1. Diagnostic Runbook: Finding Bottlenecks

### Step 1: Explain Analyze
Never guess why a query is slow. Inspect the real execution tree:
```sql
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT ...;
```
Look for:
* **`Seq Scan` (Sequential Scan)** on large tables $\rightarrow$ Missing index on filter/join condition.
* **`Sort Method: external merge Disk`** $\rightarrow$ `work_mem` too low or missing index supporting the `ORDER BY`.
* **High `Rows Removed by Filter`** $\rightarrow$ Poor selectivity or partial condition missing from index.
* **`Nested Loop` with high loops count** $\rightarrow$ Needs index on inner table join key or hash join.

---

## 2. Strategic Indexing Patterns

### B-Tree Indexes for Foreign Keys & Filters
Foreign keys are **not** indexed automatically in PostgreSQL. Always index foreign keys used in joins:
```sql
-- Foreign key index
CREATE INDEX IF NOT EXISTS idx_asistencia_curso_id ON public.asistencia (curso_id);
CREATE INDEX IF NOT EXISTS idx_asistencia_alumno_id ON public.asistencia (alumno_id);
```

### Composite Indexes (The Leftmost Prefix Rule)
When queries combine equality filters with ranges or sorts:
```sql
-- Query: WHERE curso_id = $1 AND fecha = $2 ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS idx_asistencia_curso_fecha_created 
ON public.asistencia (curso_id, fecha, created_at DESC);
```

### Partial Indexes (Huge Storage & Speed Savings)
Index only the relevant subset of rows when querying specific flags or active states:
```sql
-- Only index active courses
CREATE INDEX IF NOT EXISTS idx_cursos_activos 
ON public.cursos (profesor_id) 
WHERE estado = 'activo';

-- Only index soft-deleted records or non-deleted records
CREATE INDEX IF NOT EXISTS idx_inscripciones_activas 
ON public.inscripciones (alumno_id, curso_id) 
WHERE deleted_at IS NULL;
```

### Trigram (GIN) Indexes for Text Search
Avoid slow `ILIKE '%query%'` table scans:
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_alumnos_nombre_trgm 
ON public.alumnos USING gin (nombre_completo gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_alumnos_cedula_trgm 
ON public.alumnos USING gin (cedula gin_trgm_ops);
```

---

## 3. Query Anti-Patterns to Eliminate

| Anti-Pattern | Why It Is Slow | Optimized Alternative |
| :--- | :--- | :--- |
| `SELECT *` | Fetches unwanted columns, prevents index-only scans, increases network payload. | Explicit columns: `SELECT id, nombre, estado` |
| `WHERE UPPER(cedula) = ...` without expressional index | Bypasses standard B-Tree index on `cedula`. | Expression index `CREATE INDEX ... ON table (UPPER(cedula))` or clean data on insert. |
| N+1 Client Queries | Looping in client code to fetch children records for each parent. | Use single relational query: PostgREST embedded joins or SQL `JOIN` / `json_agg()`. |
| Unbounded `COUNT(*)` | Scans table visibility map; slow on millions of rows. | Approximate count `pg_class.reltuples` for dashboards or cached aggregate counters. |

---

## 4. Supabase Client Optimization

When querying from Flutter / Dart:
```dart
// Optimized: Select only needed columns and embed relationships in 1 roundtrip
final data = await supabase
    .from('cursos')
    .select('id, nombre, horario, perfiles:profesor_id(nombre_completo)')
    .eq('estado', 'activo');
```
* Always use `limit(n)` on pagination and infinite scroll.
* Order using an indexed column.
* Avoid redundant `.select()` re-fetches if data is already in local state.
