-- ==============================================================================
-- Migración: Crear bucket público app-updates y políticas de seguridad RLS
-- ==============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('app-updates', 'app-updates', true, 104857600)
ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = 104857600;

DO $$
BEGIN
  -- Política de lectura pública para verificar version.json y descargar paquetes de actualización
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'app_updates_public_select'
  ) THEN
    CREATE POLICY "app_updates_public_select" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'app-updates');
  END IF;

  -- Política de subida exclusiva para super_admin (o service_role)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'app_updates_superadmin_insert'
  ) THEN
    CREATE POLICY "app_updates_superadmin_insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'app-updates' AND (
        EXISTS (
          SELECT 1 FROM public.perfiles
          WHERE perfiles.id = auth.uid() AND perfiles.rol = 'super_admin'
        )
      )
    );
  END IF;

  -- Política de actualización/sobrescritura exclusiva para super_admin
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'app_updates_superadmin_update'
  ) THEN
    CREATE POLICY "app_updates_superadmin_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
      bucket_id = 'app-updates' AND (
        EXISTS (
          SELECT 1 FROM public.perfiles
          WHERE perfiles.id = auth.uid() AND perfiles.rol = 'super_admin'
        )
      )
    );
  END IF;

  -- Política de eliminación exclusiva para super_admin
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'app_updates_superadmin_delete'
  ) THEN
    CREATE POLICY "app_updates_superadmin_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (
      bucket_id = 'app-updates' AND (
        EXISTS (
          SELECT 1 FROM public.perfiles
          WHERE perfiles.id = auth.uid() AND perfiles.rol = 'super_admin'
        )
      )
    );
  END IF;
END $$;
