-- =============================================================================
-- ESQUEMA DDL - APLICACIÓN: QUINCENA (Versión 1.2)
-- Base de Datos: PostgreSQL (Supabase)
-- Novedades v1.2:
--   - Tabla 'financial_accounts' (Cuentas destino / bancarias / billeteras)
--   - Tabla 'budget_templates' con cuenta destino predefinida
--   - Enlaces de cuenta destino en 'budget_allocations' y 'transactions'
-- =============================================================================

-- 1. EXTENSIONES REQUERIDAS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. TIPOS ENUM
CREATE TYPE quincena_period_enum AS ENUM ('first_half', 'second_half');
CREATE TYPE transaction_type_enum AS ENUM ('expense', 'income_adjustment', 'transfer');
CREATE TYPE entry_method_enum AS ENUM ('manual', 'ocr');
CREATE TYPE ocr_status_enum AS ENUM ('pending', 'processed', 'failed', 'verified');
CREATE TYPE account_type_enum AS ENUM ('checking', 'savings', 'cash', 'credit_card', 'digital_wallet');

-- =============================================================================
-- TABLA: profiles
-- =============================================================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    currency VARCHAR(3) NOT NULL DEFAULT 'GTQ',
    default_income NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (default_income >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- =============================================================================
-- TABLA: financial_accounts (Cuentas Destino / Bancarias / Billeteras)
-- =============================================================================
CREATE TABLE public.financial_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name VARCHAR(80) NOT NULL,
    account_type account_type_enum NOT NULL DEFAULT 'checking',
    currency VARCHAR(3) NOT NULL DEFAULT 'GTQ',
    color_hex VARCHAR(7) NOT NULL DEFAULT '#79ADDC',
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),

    CONSTRAINT uq_user_account_name UNIQUE (user_id, name)
);

-- =============================================================================
-- TABLA: biweekly_cycles (Ciclos Quincenales)
-- =============================================================================
CREATE TABLE public.biweekly_cycles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    year SMALLINT NOT NULL CHECK (year >= 2024 AND year <= 2100),
    month SMALLINT NOT NULL CHECK (month BETWEEN 1 AND 12),
    period quincena_period_enum NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_income NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_income >= 0),
    income_destination_account_id UUID REFERENCES public.financial_accounts(id) ON DELETE SET NULL,
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    rolled_over_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    
    CONSTRAINT uq_user_cycle UNIQUE (user_id, year, month, period),
    CONSTRAINT chk_cycle_dates CHECK (start_date <= end_date)
);

-- =============================================================================
-- TABLA: categories (Categorías maestras del usuario)
-- =============================================================================
CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name VARCHAR(60) NOT NULL,
    icon VARCHAR(50) NOT NULL DEFAULT 'tag',
    color_hex VARCHAR(7) NOT NULL DEFAULT '#79ADDC',
    default_account_id UUID REFERENCES public.financial_accounts(id) ON DELETE SET NULL,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    
    CONSTRAINT uq_user_category_name UNIQUE (user_id, name)
);

-- =============================================================================
-- TABLA: budget_templates (Plantillas maestras para 1ra y 2da Quincena)
-- =============================================================================
CREATE TABLE public.budget_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    period quincena_period_enum NOT NULL, -- 'first_half' o 'second_half'
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    destination_account_id UUID REFERENCES public.financial_accounts(id) ON DELETE SET NULL,
    default_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (default_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),

    CONSTRAINT uq_user_period_category UNIQUE (user_id, period, category_id)
);

-- =============================================================================
-- TABLA: budget_allocations (Bolsas o Presupuestos del Ciclo Quincenal Activo)
-- =============================================================================
CREATE TABLE public.budget_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cycle_id UUID NOT NULL REFERENCES public.biweekly_cycles(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE RESTRICT,
    destination_account_id UUID REFERENCES public.financial_accounts(id) ON DELETE SET NULL,
    allocated_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (allocated_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),

    CONSTRAINT uq_cycle_category UNIQUE (cycle_id, category_id)
);

-- =============================================================================
-- TABLA: receipt_scans (Comprobantes procesados vía OCR)
-- =============================================================================
CREATE TABLE public.receipt_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    ocr_raw_data JSONB DEFAULT '{}'::jsonb,
    extracted_merchant TEXT,
    extracted_amount NUMERIC(12, 2),
    extracted_date DATE,
    tax_id_or_auth_number VARCHAR(100),
    suggested_account_id UUID REFERENCES public.financial_accounts(id) ON DELETE SET NULL,
    ocr_status ocr_status_enum NOT NULL DEFAULT 'pending',
    confidence_score NUMERIC(5, 2) CHECK (confidence_score BETWEEN 0.00 AND 100.00),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- =============================================================================
-- TABLA: transactions (Gastos, Pagos y Movimientos)
-- =============================================================================
CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    cycle_id UUID NOT NULL REFERENCES public.biweekly_cycles(id) ON DELETE RESTRICT,
    allocation_id UUID REFERENCES public.budget_allocations(id) ON DELETE SET NULL,
    receipt_scan_id UUID REFERENCES public.receipt_scans(id) ON DELETE SET NULL,
    source_account_id UUID NOT NULL REFERENCES public.financial_accounts(id) ON DELETE RESTRICT,
    
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    merchant_name VARCHAR(120) NOT NULL,
    transaction_date DATE NOT NULL,
    transaction_type transaction_type_enum NOT NULL DEFAULT 'expense',
    entry_method entry_method_enum NOT NULL DEFAULT 'manual',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- =============================================================================
-- ÍNDICES DE RENDIMIENTO Y PREVENCIÓN DE DUPLICADOS
-- =============================================================================
CREATE INDEX idx_accounts_user ON public.financial_accounts(user_id);
CREATE INDEX idx_cycles_user_dates ON public.biweekly_cycles(user_id, start_date, end_date);
CREATE INDEX idx_templates_user_period ON public.budget_templates(user_id, period);
CREATE INDEX idx_allocations_cycle ON public.budget_allocations(cycle_id);
CREATE INDEX idx_allocations_account ON public.budget_allocations(destination_account_id);
CREATE INDEX idx_transactions_cycle ON public.transactions(cycle_id);
CREATE INDEX idx_transactions_account ON public.transactions(source_account_id);
CREATE INDEX idx_transactions_user_date ON public.transactions(user_id, transaction_date DESC);
CREATE INDEX idx_receipt_scans_ocr_gin ON public.receipt_scans USING gin(ocr_raw_data);
CREATE INDEX idx_transactions_dup_check ON public.transactions(user_id, merchant_name, amount, transaction_date);

-- =============================================================================
-- SEGURIDAD A NIVEL DE FILA (ROW LEVEL SECURITY - RLS)
-- =============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biweekly_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipt_scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own profile" ON public.profiles FOR ALL USING (auth.uid() = id);
CREATE POLICY "Users can manage own accounts" ON public.financial_accounts FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own cycles" ON public.biweekly_cycles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own categories" ON public.categories FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own templates" ON public.budget_templates FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own scans" ON public.receipt_scans FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own transactions" ON public.transactions FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own budget allocations" ON public.budget_allocations
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.biweekly_cycles c
            WHERE c.id = budget_allocations.cycle_id AND c.user_id = auth.uid()
        )
    );

-- =============================================================================
-- TRIGGERS Y FUNCIONES
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();
CREATE TRIGGER trg_accounts_updated_at BEFORE UPDATE ON public.financial_accounts FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();
CREATE TRIGGER trg_cycles_updated_at BEFORE UPDATE ON public.biweekly_cycles FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();
CREATE TRIGGER trg_templates_updated_at BEFORE UPDATE ON public.budget_templates FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();
CREATE TRIGGER trg_allocations_updated_at BEFORE UPDATE ON public.budget_allocations FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();
CREATE TRIGGER trg_transactions_updated_at BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();

-- Crear cuenta por defecto ('Efectivo') y perfil al registrar usuario
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_profile_id UUID;
    default_acc_id UUID;
BEGIN
    INSERT INTO public.profiles (id, full_name, default_income)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', ''), 0.00)
    RETURNING id INTO new_profile_id;

    INSERT INTO public.financial_accounts (user_id, name, account_type, is_default, color_hex)
    VALUES (new_profile_id, 'Efectivo / Billetera', 'cash', TRUE, '#ADF7B6')
    RETURNING id INTO default_acc_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
