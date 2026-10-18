-- =============================================================================
-- MIGRACIÓN v1.4: Mantenimiento de Categorías y Alta de Partida en Plantilla
-- Requerimientos: RF-CAT-01, RF-PLANT-02, RN-CAT-01, RN-CAT-02
-- =============================================================================

-- 1. Asegurar índice único case-insensitive para categorías activas por usuario (CA-C1.2)
CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_user_name_active 
    ON public.categories (user_id, LOWER(TRIM(name)))
    WHERE is_archived = FALSE;

-- 2. Función helper para inicializar categorías semilla para un usuario (RN-CAT-02)
CREATE OR REPLACE FUNCTION public.seed_user_default_categories(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.categories (user_id, name, icon, color_hex, is_archived)
    VALUES
        (p_user_id, 'Supermercado', 'shopping_cart', '#ADF7B6', FALSE),
        (p_user_id, 'Vivienda & Servicios', 'home', '#79ADDC', FALSE),
        (p_user_id, 'Transporte', 'directions_car', '#FFC09F', FALSE),
        (p_user_id, 'Alimentación', 'restaurant', '#FFEE93', FALSE),
        (p_user_id, 'Ahorro', 'savings', '#FCF5C7', FALSE),
        (p_user_id, 'Ocio', 'local_cafe', '#79ADDC', FALSE)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Actualizar función handle_new_user() para aprovisionar categorías iniciales (RN-CAT-02)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_profile_id UUID;
    extracted_full_name TEXT;
    default_acc_id UUID;
BEGIN
    extracted_full_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name',
        ''
    );

    -- 1. Crear Perfil
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

    -- 2. Crear Cuenta por Defecto
    INSERT INTO public.financial_accounts (
        user_id,
        name,
        account_type,
        currency,
        color_hex,
        icon,
        initial_balance,
        is_default
    )
    VALUES (
        new_profile_id,
        'Efectivo / Billetera',
        'cash',
        'GTQ',
        '#ADF7B6',
        'wallet',
        0.00,
        TRUE
    )
    ON CONFLICT (user_id, name) DO NOTHING
    RETURNING id INTO default_acc_id;

    -- 3. Sembrar Categorías Semilla (RN-CAT-02)
    PERFORM public.seed_user_default_categories(new_profile_id);

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user exception para usuario %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-vincular trigger en auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 4. Sembrar categorías en perfiles existentes que no tengan categorías activas
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT id FROM public.profiles LOOP
        PERFORM public.seed_user_default_categories(r.id);
    END LOOP;
END;
$$;
