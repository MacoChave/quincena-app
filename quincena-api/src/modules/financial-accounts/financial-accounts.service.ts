import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import { CreateFinancialAccountDto } from './dto/create-financial-account.dto';
import { UpdateFinancialAccountDto } from './dto/update-financial-account.dto';

@Injectable()
export class FinancialAccountsService {
  constructor(private readonly supabase: SupabaseService) {}

  /**
   * Lista cuentas financieras del usuario calculando current_balance
   * (saldo inicial menos gastos de transacciones asociadas).
   */
  async findAll(userId: string, accessToken: string, includeArchived = false) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    let query = client
      .from('financial_accounts')
      .select('*')
      .eq('user_id', userId)
      .order('is_default', { ascending: false })
      .order('name');

    if (!includeArchived) {
      query = query.eq('is_archived', false);
    }

    const { data: accounts, error } = await query;
    if (error) throw new Error(error.message);

    // Obtener transacciones del usuario para calcular el saldo actual real por cuenta
    const { data: transactions } = await client
      .from('transactions')
      .select('source_account_id, amount, transaction_type')
      .eq('user_id', userId);

    const spentMap = new Map<string, number>();
    for (const tx of transactions ?? []) {
      if (tx.source_account_id) {
        const amt = Number(tx.amount) || 0;
        const currentSpent = spentMap.get(tx.source_account_id) ?? 0;
        if (tx.transaction_type === 'income_adjustment') {
          spentMap.set(tx.source_account_id, currentSpent - amt);
        } else {
          spentMap.set(tx.source_account_id, currentSpent + amt);
        }
      }
    }

    return (accounts ?? []).map((acc) => {
      const initial = Number(acc.initial_balance ?? 0);
      const spent = spentMap.get(acc.id) ?? 0;
      const current = Math.round((initial - spent) * 100) / 100;

      return {
        ...acc,
        initial_balance: initial,
        current_balance: current,
        icon: acc.icon ?? 'account_balance',
      };
    });
  }

  async create(
    userId: string,
    dto: CreateFinancialAccountDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // Si se marca como default, des-marcar la anterior
    if (dto.is_default) {
      await client
        .from('financial_accounts')
        .update({ is_default: false })
        .eq('user_id', userId)
        .eq('is_default', true);
    }

    const initialBalance =
      dto.initial_balance !== undefined ? Number(dto.initial_balance) : 0;
    const icon = dto.icon ?? 'account_balance';

    const { data, error } = await client
      .from('financial_accounts')
      .insert({
        ...dto,
        user_id: userId,
        initial_balance: initialBalance,
        icon,
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        throw new ConflictException(
          `Ya existe una cuenta con el nombre "${dto.name}"`,
        );
      }
      throw new Error(error.message);
    }

    return {
      ...data,
      initial_balance: Number(data.initial_balance ?? initialBalance),
      current_balance: Number(data.initial_balance ?? initialBalance),
      icon: data.icon ?? icon,
    };
  }

  async update(
    id: string,
    userId: string,
    dto: UpdateFinancialAccountDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // Si se marca como default, des-marcar la anterior
    if (dto.is_default) {
      await client
        .from('financial_accounts')
        .update({ is_default: false })
        .eq('user_id', userId)
        .eq('is_default', true)
        .neq('id', id);
    }

    const { data, error } = await client
      .from('financial_accounts')
      .update({ ...dto, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .single();

    if (error || !data) throw new NotFoundException('Cuenta no encontrada');

    // Calcular current_balance
    const { data: txs } = await client
      .from('transactions')
      .select('amount, transaction_type')
      .eq('source_account_id', id);

    let spent = 0;
    for (const tx of txs ?? []) {
      const amt = Number(tx.amount) || 0;
      if (tx.transaction_type === 'income_adjustment') {
        spent -= amt;
      } else {
        spent += amt;
      }
    }

    const initial = Number(data.initial_balance ?? 0);
    const current = Math.round((initial - spent) * 100) / 100;

    return {
      ...data,
      initial_balance: initial,
      current_balance: current,
      icon: data.icon ?? 'account_balance',
    };
  }

  async archive(id: string, userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { data, error } = await client
      .from('financial_accounts')
      .update({ is_archived: true, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .single();

    if (error || !data) throw new NotFoundException('Cuenta no encontrada');
    return { message: 'Cuenta archivada exitosamente', account: data };
  }

  async unarchive(id: string, userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { data, error } = await client
      .from('financial_accounts')
      .update({ is_archived: false, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .single();

    if (error || !data) throw new NotFoundException('Cuenta no encontrada');
    return { message: 'Cuenta desarchivada exitosamente', account: data };
  }
}
