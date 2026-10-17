-- =============================================================================
-- MIGRACIÓN: QUINCENA (Versión 1.3)
-- Descripción:
--   1. Agrega columna 'is_active' a la tabla 'profiles'
--   2. Modifica foreign keys en 'budget_allocations' y 'transactions' a ON DELETE CASCADE
--   3. Actualiza función 'handle_new_user'
--   4. Agrega función 'delete_user_account' (Baja y eliminación de cuenta autoservicio)
--      con purga de archivos de comprobantes en storage.objects
-- =============================================================================

-- 1. Agregar columna 'is_active' en profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- 2. Actualizar claves foráneas para borrado en cascada (ON DELETE CASCADE)
-- En budget_allocations -> categories
ALTER TABLE public.budget_allocations
  DROP CONSTRAINT IF EXISTS budget_allocations_category_id_fkey,
  ADD CONSTRAINT budget_allocations_category_id_fkey
    FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;

-- En transactions -> biweekly_cycles
ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_cycle_id_fkey,
  ADD CONSTRAINT transactions_cycle_id_fkey
    FOREIGN KEY (cycle_id) REFERENCES public.biweekly_cycles(id) ON DELETE CASCADE;

-- 3. Actualizar función de registro de nuevo usuario
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_profile_id UUID;
BEGIN
    INSERT INTO public.profiles (id, full_name, default_income)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', ''), 0.00)
    RETURNING id INTO new_profile_id;

    INSERT INTO public.financial_accounts (user_id, name, account_type, is_default, color_hex)
    VALUES (new_profile_id, 'Efectivo / Billetera', 'cash', TRUE, '#ADF7B6');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Procedimiento de Baja Voluntaria de Cuenta (Autoservicio - RF-AUTH-04)
-- Permite que un usuario autenticado invoque su propia eliminación total (GDPR / tiendas de apps)
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS VOID AS $$
DECLARE
    current_user_id UUID;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado';
    END IF;

    -- Purgar archivos e imágenes de comprobantes en storage asociados al usuario (CA-A4.4)
    DELETE FROM storage.objects
    WHERE bucket_id = 'receipts'
      AND (storage.foldername(name))[1] = current_user_id::text;

    -- Al eliminar el registro de auth.users, el ON DELETE CASCADE se propaga
    -- a profiles y a todas las tablas del esquema public
    DELETE FROM auth.users WHERE id = current_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Permisos de ejecución para la función de baja de cuenta
REVOKE EXECUTE ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
