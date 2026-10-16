-- =============================================================================
-- STORAGE BUCKET & POLICIES - APLICACIÓN: QUINCENA
-- Bucket: receipts (Comprobantes procesados vía OCR / archivos adjuntos)
-- =============================================================================

-- 1. Crear el bucket 'receipts' si no existe (privado)
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

-- 2. Políticas de Seguridad RLS en storage.objects
-- Convención de rutas: receipts/<user_id>/<file>
CREATE POLICY "User receipt upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'receipts' AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "User receipt access" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'receipts' AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "User receipt update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'receipts' AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "User receipt delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'receipts' AND (storage.foldername(name))[1] = auth.uid()::text
  );
