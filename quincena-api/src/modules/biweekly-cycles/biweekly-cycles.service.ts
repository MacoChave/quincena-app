import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import { CreateBiweeklyCycleDto } from './dto/create-biweekly-cycle.dto';
import { UpdateBiweeklyCycleDto } from './dto/update-biweekly-cycle.dto';
import { CloseCycleDto, RolloverAction } from './dto/close-cycle.dto';

@Injectable()
export class BiweeklyCyclesService {
  constructor(private readonly supabase: SupabaseService) {}

  async findAll(userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { data, error } = await client
      .from('biweekly_cycles')
      .select('*')
      .eq('user_id', userId)
      .order('year', { ascending: false })
      .order('month', { ascending: false })
      .order('period', { ascending: false });

    if (error) throw new Error(error.message);
    return data;
  }

  async findCurrent(userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const today = new Date().toISOString().split('T')[0];

    const { data, error } = await client
      .from('biweekly_cycles')
      .select('*')
      .eq('user_id', userId)
      .eq('is_closed', false)
      .lte('start_date', today)
      .gte('end_date', today)
      .single();

    if (error || !data) {
      // Si no hay ciclo activo, devolver el más reciente abierto
      const { data: recent } = await client
        .from('biweekly_cycles')
        .select('*')
        .eq('user_id', userId)
        .eq('is_closed', false)
        .order('start_date', { ascending: false })
        .limit(1)
        .single();

      if (!recent) throw new NotFoundException('No hay ciclo quincenal activo');
      return recent;
    }
    return data;
  }

  async findOne(id: string, userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { data, error } = await client
      .from('biweekly_cycles')
      .select('*')
      .eq('id', id)
      .eq('user_id', userId)
      .single();

    if (error || !data) throw new NotFoundException('Ciclo no encontrado');
    return data;
  }

  async create(
    userId: string,
    dto: CreateBiweeklyCycleDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    const { data, error } = await client
      .from('biweekly_cycles')
      .insert({ ...dto, user_id: userId })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        throw new ConflictException(
          'Ya existe un ciclo para este período (año/mes/período)',
        );
      }
      throw new Error(error.message);
    }
    return data;
  }

  async update(
    id: string,
    userId: string,
    dto: UpdateBiweeklyCycleDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // RN-01: No modificar ciclos cerrados
    const existing = await this.findOne(id, userId, accessToken);
    if (existing.is_closed) {
      throw new BadRequestException(
        'No se puede modificar un ciclo quincenal cerrado (RN-01)',
      );
    }

    const { data, error } = await client
      .from('biweekly_cycles')
      .update({ ...dto, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .single();

    if (error || !data) throw new NotFoundException('Ciclo no encontrado');
    return data;
  }

  /**
   * Cierra el ciclo quincenal e implementa la lógica de remanente (CA-01.2).
   * Calcula el saldo restante y aplica la acción elegida por el usuario.
   */
  async close(
    id: string,
    userId: string,
    dto: CloseCycleDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    const cycle = await this.findOne(id, userId, accessToken);
    if (cycle.is_closed) {
      throw new BadRequestException('El ciclo ya está cerrado');
    }

    // Calcular remanente: ingreso - suma de transacciones del ciclo
    const { data: txData } = await client
      .from('transactions')
      .select('amount')
      .eq('cycle_id', id);

    const totalSpent = (txData ?? []).reduce(
      (sum: number, tx: { amount: number }) => sum + Number(tx.amount),
      0,
    );
    const remainder = Number(cycle.total_income) - totalSpent;

    let rolledOverAmount = 0;

    if (dto.rollover_action === RolloverAction.ADD_TO_NEW_CYCLE) {
      rolledOverAmount = remainder;
    } else if (dto.rollover_action === RolloverAction.TRANSFER_TO_SAVINGS) {
      if (!dto.savings_account_id) {
        throw new BadRequestException(
          'Se requiere savings_account_id para transferir a cuenta de ahorro',
        );
      }
      rolledOverAmount = 0;
      // La transferencia real a la cuenta de ahorro se puede implementar con
      // una transacción de tipo 'transfer' en el ciclo siguiente
    }
    // Si rollover_action === 'archive', rolledOverAmount queda en 0

    const { data, error } = await client
      .from('biweekly_cycles')
      .update({
        is_closed: true,
        rolled_over_amount: rolledOverAmount,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .single();

    if (error || !data) throw new NotFoundException('Ciclo no encontrado');

    return {
      cycle: data,
      summary: {
        total_income: cycle.total_income,
        total_spent: totalSpent,
        remainder,
        rollover_action: dto.rollover_action,
        rolled_over_amount: rolledOverAmount,
      },
    };
  }
}
