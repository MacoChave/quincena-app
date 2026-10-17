-- =============================================================================
-- MIGRACIÓN CORRECTIVA: Asegurar columna 'full_name' y robustecer 'handle_new_user'
-- =============================================================================

-- 1. Garantizar la existencia de columnas en public.profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS full_name TEXT;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS currency VARCHAR(3) NOT NULL DEFAULT 'GTQ';

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS default_income NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- 2. Función robusta e idempotente para el registro de nuevos usuarios
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_profile_id UUID;
    extracted_full_name TEXT;
BEGIN
    -- Extraer de forma segura full_name o name desde raw_user_meta_data
    extracted_full_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name',
        ''
    );

    -- Insertar o actualizar el perfil de forma segura
    INSERT INTO public.profiles (id, full_name, default_income, is_active)
    VALUES (NEW.id, extracted_full_name, 0.00, TRUE)
    ON CONFLICT (id) DO UPDATE
    SET 
        full_name = CASE 
            WHEN public.profiles.full_name IS NULL OR public.profiles.full_name = '' 
            THEN EXCLUDED.full_name 
            ELSE public.profiles.full_name 
        END,
        updated_at = TIMEZONE('utc', NOW())
    RETURNING id INTO new_profile_id;

    -- Asegurar creación de cuenta inicial ('Efectivo / Billetera')
    INSERT INTO public.financial_accounts (user_id, name, account_type, is_default, color_hex)
    VALUES (new_profile_id, 'Efectivo / Billetera', 'cash', TRUE, '#ADF7B6')
    ON CONFLICT (user_id, name) DO NOTHING;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Registrar advertencia en logs de PostgreSQL sin abortar la creación del usuario en auth
        RAISE WARNING 'handle_new_user exception para usuario %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Asegurar que el trigger esté vinculado en auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
