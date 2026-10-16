import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { UpdateTransactionDto } from './dto/update-transaction.dto';

@Injectable()
export class TransactionsService {
  constructor(private readonly supabase: SupabaseService) {}

  async findByCycle(cycleId: string, userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { data, error } = await client
      .from('transactions')
      .select(
        '*, budget_allocations(id, categories(id, name, icon, color_hex)), source_account:financial_accounts(id, name, color_hex)',
      )
      .eq('cycle_id', cycleId)
      .eq('user_id', userId)
      .order('transaction_date', { ascending: false })
      .order('created_at', { ascending: false });

    if (error) throw new Error(error.message);
    return data;
  }

  /**
   * Registra un gasto manual con detección de duplicados (RN-03).
   * Busca transacciones con el mismo comercio, monto y fecha ±24h.
   * Si encuentra un posible duplicado, lanza ConflictException con advertencia.
   * El cliente puede forzar el registro enviando force_create=true.
   */
  async create(
    userId: string,
    dto: CreateTransactionDto,
    accessToken: string,
    forceCreate = false,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // RN-01: Verificar que el ciclo esté abierto
    const { data: cycle } = await client
      .from('biweekly_cycles')
      .select('is_closed')
      .eq('id', dto.cycle_id)
      .eq('user_id', userId)
      .single();

    if (!cycle) throw new NotFoundException('Ciclo no encontrado');
    if (cycle.is_closed) {
      throw new BadRequestException(
        'No se pueden registrar gastos en un ciclo cerrado (RN-01)',
      );
    }

    // RN-03: Detección de duplicados — misma fecha, mismo monto, mismo comercio ±24h
    if (!forceCreate) {
      const txDate = new Date(dto.transaction_date);
      const dayBefore = new Date(txDate);
      dayBefore.setDate(dayBefore.getDate() - 1);
      const dayAfter = new Date(txDate);
      dayAfter.setDate(dayAfter.getDate() + 1);

      const { data: duplicates } = await client
        .from('transactions')
        .select('id, merchant_name, amount, transaction_date, created_at')
        .eq('user_id', userId)
        .eq('merchant_name', dto.merchant_name)
        .eq('amount', dto.amount)
        .gte('transaction_date', dayBefore.toISOString().split('T')[0])
        .lte('transaction_date', dayAfter.toISOString().split('T')[0]);

      if (duplicates && duplicates.length > 0) {
        throw new ConflictException({
          message:
            'Parece que este gasto ya fue registrado. ¿Deseas continuar de todas formas? (RN-03)',
          duplicate_warning: true,
          existing_transactions: duplicates,
        });
      }
    }

    const { data, error } = await client
      .from('transactions')
      .insert({ ...dto, user_id: userId })
      .select(
        '*, budget_allocations(id, categories(id, name, icon, color_hex)), source_account:financial_accounts(id, name, color_hex)',
      )
      .single();

    if (error) throw new Error(error.message);
    return data;
  }

  async update(
    id: string,
    userId: string,
    dto: UpdateTransactionDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    const { data, error } = await client
      .from('transactions')
      .update({ ...dto, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .single();

    if (error || !data) throw new NotFoundException('Transacción no encontrada');
    return data;
  }

  async remove(id: string, userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    const { error } = await client
      .from('transactions')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);

    if (error) throw new Error(error.message);
    return { message: 'Transacción eliminada exitosamente' };
  }
}
