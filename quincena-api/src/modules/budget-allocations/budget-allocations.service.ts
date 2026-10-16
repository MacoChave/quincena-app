import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import { CreateBudgetAllocationDto } from './dto/create-budget-allocation.dto';
import { UpdateBudgetAllocationDto } from './dto/update-budget-allocation.dto';

export interface AllocationWithSpent {
  id: string;
  cycle_id: string;
  category_id: string;
  destination_account_id: string | null;
  allocated_amount: number;
  spent_amount: number;
  available_amount: number;
  spent_percentage: number;
  categories: { id: string; name: string; icon: string; color_hex: string } | null;
  destination_account: { id: string; name: string; color_hex: string } | null;
}

@Injectable()
export class BudgetAllocationsService {
  constructor(private readonly supabase: SupabaseService) {}

  /**
   * Devuelve las asignaciones de un ciclo con el monto gastado y disponible.
   * Implementa CA-02.1: cálculo de "Por Asignar" = Ingresos - Suma de categorías.
   */
  async findByCycle(
    cycleId: string,
    userId: string,
    accessToken: string,
  ): Promise<{ allocations: AllocationWithSpent[]; summary: object }> {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // Verificar que el ciclo pertenece al usuario
    const { data: cycle, error: cycleError } = await client
      .from('biweekly_cycles')
      .select('id, total_income, is_closed')
      .eq('id', cycleId)
      .eq('user_id', userId)
      .single();

    if (cycleError || !cycle) throw new NotFoundException('Ciclo no encontrado');

    // Obtener asignaciones con sus categorías y cuentas destino
    const { data: allocations, error: allocError } = await client
      .from('budget_allocations')
      .select(
        '*, categories(id, name, icon, color_hex), destination_account:financial_accounts(id, name, color_hex)',
      )
      .eq('cycle_id', cycleId)
      .order('categories(name)');

    if (allocError) throw new Error(allocError.message);

    // Obtener transacciones del ciclo para calcular gasto real por categoría
    const { data: transactions } = await client
      .from('transactions')
      .select('allocation_id, amount')
      .eq('cycle_id', cycleId);

    // Mapa de gasto por allocation_id
    const spentMap = new Map<string, number>();
    for (const tx of transactions ?? []) {
      if (tx.allocation_id) {
        spentMap.set(
          tx.allocation_id,
          (spentMap.get(tx.allocation_id) ?? 0) + Number(tx.amount),
        );
      }
    }

    const enrichedAllocations: AllocationWithSpent[] = (allocations ?? []).map(
      (alloc: Record<string, unknown>) => {
        const spent = spentMap.get(alloc.id as string) ?? 0;
        const allocated = Number(alloc.allocated_amount);
        const available = allocated - spent;
        const percentage = allocated > 0 ? (spent / allocated) * 100 : 0;
        return {
          ...alloc,
          spent_amount: spent,
          available_amount: available,
          spent_percentage: Math.round(percentage * 100) / 100,
        } as AllocationWithSpent;
      },
    );

    const totalAllocated = enrichedAllocations.reduce(
      (sum, a) => sum + a.allocated_amount,
      0,
    );
    const totalSpent = enrichedAllocations.reduce(
      (sum, a) => sum + a.spent_amount,
      0,
    );

    return {
      allocations: enrichedAllocations,
      summary: {
        total_income: cycle.total_income,
        total_allocated: totalAllocated,
        unallocated: Number(cycle.total_income) - totalAllocated, // "Por Asignar" CA-02.1
        total_spent: totalSpent,
        total_available: totalAllocated - totalSpent,
        is_balanced: Math.abs(Number(cycle.total_income) - totalAllocated) < 0.01,
        is_closed: cycle.is_closed,
      },
    };
  }

  async create(
    userId: string,
    dto: CreateBudgetAllocationDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // RN-01: Verificar que el ciclo no esté cerrado
    const { data: cycle } = await client
      .from('biweekly_cycles')
      .select('is_closed')
      .eq('id', dto.cycle_id)
      .eq('user_id', userId)
      .single();

    if (!cycle) throw new NotFoundException('Ciclo no encontrado');
    if (cycle.is_closed) {
      throw new BadRequestException(
        'No se pueden agregar asignaciones a un ciclo cerrado (RN-01)',
      );
    }

    const { data, error } = await client
      .from('budget_allocations')
      .insert(dto)
      .select('*, categories(id, name, icon, color_hex)')
      .single();

    if (error) {
      if (error.code === '23505') {
        throw new ConflictException(
          'Ya existe una asignación para esta categoría en este ciclo',
        );
      }
      throw new Error(error.message);
    }
    return data;
  }

  /**
   * RN-02: Rebalanceo inter-categorías.
   * Permite reasignar fondos sin alterar el ingreso total del ciclo.
   */
  async update(
    id: string,
    userId: string,
    dto: UpdateBudgetAllocationDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // Verificar ownership vía join con el ciclo
    const { data: existing } = await client
      .from('budget_allocations')
      .select('id, cycle_id, biweekly_cycles!inner(user_id, is_closed)')
      .eq('id', id)
      .single();

    if (!existing) throw new NotFoundException('Asignación no encontrada');

    const cycle = (existing as Record<string, unknown>).biweekly_cycles as {
      user_id: string;
      is_closed: boolean;
    };

    if (cycle.user_id !== userId) throw new NotFoundException('Asignación no encontrada');
    if (cycle.is_closed) {
      throw new BadRequestException(
        'No se puede modificar una asignación en un ciclo cerrado (RN-01)',
      );
    }

    const { data, error } = await client
      .from('budget_allocations')
      .update({ ...dto, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single();

    if (error || !data) throw new NotFoundException('Asignación no encontrada');
    return data;
  }

  async remove(id: string, userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // Verificar ownership
    const { data: existing } = await client
      .from('budget_allocations')
      .select('id, biweekly_cycles!inner(user_id)')
      .eq('id', id)
      .single();

    if (!existing) throw new NotFoundException('Asignación no encontrada');

    const { error } = await client
      .from('budget_allocations')
      .delete()
      .eq('id', id);

    if (error) throw new Error(error.message);
    return { message: 'Asignación eliminada exitosamente' };
  }
}
