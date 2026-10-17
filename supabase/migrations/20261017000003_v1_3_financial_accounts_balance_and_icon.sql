-- =============================================================================
-- MIGRACIÓN: QUINCENA (Versión 1.3 - RF-01 / CA-01.1)
-- Archivo: 20261017000003_v1_3_financial_accounts_balance_and_icon.sql
-- Descripción:
--   1. Agrega columna 'initial_balance' (NUMERIC(12,2) >= 0) a 'financial_accounts'.
--   2. Agrega columna 'icon' (VARCHAR(50)) a 'financial_accounts' con default 'account_balance'.
--   3. Actualiza trigger 'handle_new_user' para inicializar 'Efectivo / Billetera'
--      con initial_balance = 0.00 e icon = 'wallet'.
--   4. Función PL/pgSQL helper 'calculate_account_current_balance' para obtener
--      el balance actual en tiempo de ejecución.
--   5. Vista 'v_financial_accounts_balance' con cálculo dinámico de current_balance.
-- =============================================================================

-- 1. Agregar columna 'initial_balance' a 'financial_accounts'
ALTER TABLE public.financial_accounts
    ADD COLUMN IF NOT EXISTS initial_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- Asegurar constraint de saldo inicial no negativo
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_financial_accounts_initial_balance'
    ) THEN
        ALTER TABLE public.financial_accounts
            ADD CONSTRAINT chk_financial_accounts_initial_balance CHECK (initial_balance >= 0);
    END IF;
END $$;

-- 2. Agregar columna 'icon' a 'financial_accounts'
ALTER TABLE public.financial_accounts
    ADD COLUMN IF NOT EXISTS icon VARCHAR(50) NOT NULL DEFAULT 'account_balance';

-- Normalizar cuentas por defecto existentes para usar icono 'wallet'
UPDATE public.financial_accounts
SET icon = 'wallet'
WHERE name = 'Efectivo / Billetera' AND (icon = 'account_balance' OR icon IS NULL);

-- 3. Actualizar función 'handle_new_user' para incluir initial_balance e icon
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

    -- Asegurar creación de cuenta inicial ('Efectivo / Billetera') con saldo inicial 0.00 e ícono wallet
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
    ON CONFLICT (user_id, name) DO NOTHING;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Registrar advertencia en logs de PostgreSQL sin abortar la creación del usuario en auth
        RAISE WARNING 'handle_new_user exception para usuario %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-vincular trigger en auth.users de manera idempotente
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 4. Función PL/pgSQL helper para calcular el saldo actual de una cuenta
CREATE OR REPLACE FUNCTION public.calculate_account_current_balance(p_account_id UUID)
RETURNS NUMERIC(12, 2)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_initial NUMERIC(12, 2);
    v_spent NUMERIC(12, 2);
BEGIN
    SELECT initial_balance INTO v_initial
    FROM public.financial_accounts
    WHERE id = p_account_id;

    IF NOT FOUND THEN
        RETURN 0.00;
    END IF;

    SELECT COALESCE(SUM(
        CASE 
            WHEN transaction_type = 'income_adjustment' THEN -amount
            ELSE amount
        END
    ), 0.00) INTO v_spent
    FROM public.transactions
    WHERE source_account_id = p_account_id;

    RETURN (v_initial - v_spent);
END;
$$;

-- 5. Vista de conveniencia para consultar cuentas con su saldo calculado en tiempo real
DO $$
BEGIN
    BEGIN
        CREATE OR REPLACE VIEW public.v_financial_accounts_balance
        WITH (security_invoker = true)
        AS
        SELECT
            fa.id,
            fa.user_id,
            fa.name,
            fa.account_type,
            fa.currency,
            fa.color_hex,
            fa.icon,
            fa.is_default,
            fa.is_archived,
            fa.initial_balance,
            (
                fa.initial_balance - COALESCE(
                    SUM(
                        CASE 
                            WHEN t.transaction_type = 'income_adjustment' THEN -t.amount
                            ELSE t.amount
                        END
                    ),
                    0.00
                )
            )::NUMERIC(12, 2) AS current_balance,
            fa.created_at,
            fa.updated_at
        FROM public.financial_accounts fa
        LEFT JOIN public.transactions t ON t.source_account_id = fa.id
        GROUP BY fa.id;
    EXCEPTION
        WHEN OTHERS THEN
            -- Compatibilidad para versiones de PostgreSQL que no soporten security_invoker en CREATE VIEW
            CREATE OR REPLACE VIEW public.v_financial_accounts_balance
            AS
            SELECT
                fa.id,
                fa.user_id,
                fa.name,
                fa.account_type,
                fa.currency,
                fa.color_hex,
                fa.icon,
                fa.is_default,
                fa.is_archived,
                fa.initial_balance,
                (
                    fa.initial_balance - COALESCE(
                        SUM(
                            CASE 
                                WHEN t.transaction_type = 'income_adjustment' THEN -t.amount
                                ELSE t.amount
                            END
                        ),
                        0.00
                    )
                )::NUMERIC(12, 2) AS current_balance,
                fa.created_at,
                fa.updated_at
            FROM public.financial_accounts fa
            LEFT JOIN public.transactions t ON t.source_account_id = fa.id
            GROUP BY fa.id;
    END;
END $$;

-- 6. Asignación de permisos
GRANT SELECT ON public.v_financial_accounts_balance TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_account_current_balance(UUID) TO authenticated, service_role;
