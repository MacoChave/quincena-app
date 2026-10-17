import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import { BudgetAllocationsService } from '../budget-allocations/budget-allocations.service';
import {
  CreateBiweeklyCycleDto,
  QuincenaPeriod,
} from './dto/create-biweekly-cycle.dto';
import { UpdateBiweeklyCycleDto } from './dto/update-biweekly-cycle.dto';
import { CloseCycleDto, RolloverAction } from './dto/close-cycle.dto';
import { InitCurrentCycleDto } from './dto/init-current-cycle.dto';
import {
  DashboardResponseDto,
  DashboardCategoryDto,
  SuggestedPeriodDto,
} from './dto/dashboard-response.dto';

@Injectable()
export class BiweeklyCyclesService {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly budgetAllocationsService: BudgetAllocationsService,
  ) {}

  /**
   * Calcula el período quincenal sugerido en base a la fecha actual del sistema.
   */
  getSuggestedPeriod(): SuggestedPeriodDto {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const isFirstHalf = now.getDate() <= 15;
    const period = isFirstHalf
      ? QuincenaPeriod.FIRST_HALF
      : QuincenaPeriod.SECOND_HALF;
    const monthStr = String(month).padStart(2, '0');
    const startDate = `${year}-${monthStr}-${isFirstHalf ? '01' : '16'}`;
    const lastDay = new Date(year, month, 0).getDate();
    const endDate = `${year}-${monthStr}-${isFirstHalf ? '15' : String(lastDay).padStart(2, '0')}`;

    return {
      year,
      month,
      period,
      start_date: startDate,
      end_date: endDate,
    };
  }

  /**
   * Endpoint consolidado para el Dashboard móvil (Quincena Activa).
   * Devuelve estado del ciclo actual, resumen presupuestario y gastos por categoría en un solo roundtrip.
   */
  async getDashboard(
    userId: string,
    accessToken: string,
  ): Promise<DashboardResponseDto> {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const today = new Date().toISOString().split('T')[0];

    // 1. Buscar ciclo activo que incluya la fecha de hoy
    let activeCycle = null;

    const { data: currentCycle } = await client
      .from('biweekly_cycles')
      .select('*')
      .eq('user_id', userId)
      .eq('is_closed', false)
      .lte('start_date', today)
      .gte('end_date', today)
      .maybeSingle();

    if (currentCycle) {
      activeCycle = currentCycle;
    } else {
      // Si no hay ciclo que contenga hoy, buscar el más reciente abierto
      const { data: recentOpen } = await client
        .from('biweekly_cycles')
        .select('*')
        .eq('user_id', userId)
        .eq('is_closed', false)
        .order('start_date', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (recentOpen) {
        activeCycle = recentOpen;
      }
    }

    // 2. Si no hay ningún ciclo activo, devolver sugerencia de período para inicializar
    if (!activeCycle) {
      return {
        has_active_cycle: false,
        cycle: null,
        summary: {
          total_income: 0,
          total_allocated: 0,
          total_spent: 0,
          total_available: 0,
          unallocated: 0,
          is_balanced: false,
        },
        categories: [],
        suggested_period: this.getSuggestedPeriod(),
      };
    }

    // 3. Ciclo activo encontrado: obtener asignaciones y gastos acumulados
    const { allocations, summary } =
      await this.budgetAllocationsService.findByCycle(
        activeCycle.id,
        userId,
        accessToken,
      );

    const categories: DashboardCategoryDto[] = (allocations ?? []).map(
      (alloc) => ({
        id: alloc.id,
        category_id: alloc.category_id,
        name: alloc.categories?.name ?? 'Categoría',
        icon: alloc.categories?.icon ?? 'category',
        color_hex: alloc.categories?.color_hex ?? '#79ADDC',
        allocated_amount: Number(alloc.allocated_amount),
        spent_amount: Number(alloc.spent_amount),
        available_amount: Number(alloc.available_amount),
        spent_percentage: Number(alloc.spent_percentage),
      }),
    );

    const summaryData = summary as {
      total_income: number | string;
      total_allocated: number;
      total_spent: number;
      total_available: number;
      unallocated: number;
      is_balanced: boolean;
    };

    return {
      has_active_cycle: true,
      cycle: {
        id: activeCycle.id,
        year: activeCycle.year,
        month: activeCycle.month,
        period: activeCycle.period,
        start_date: activeCycle.start_date,
        end_date: activeCycle.end_date,
        total_income: Number(activeCycle.total_income),
        is_closed: activeCycle.is_closed,
        income_destination_account_id:
          activeCycle.income_destination_account_id,
        rolled_over_amount: Number(activeCycle.rolled_over_amount ?? 0),
        created_at: activeCycle.created_at,
        updated_at: activeCycle.updated_at,
      },
      summary: {
        total_income: Number(summaryData.total_income),
        total_allocated: Number(summaryData.total_allocated),
        total_spent: Number(summaryData.total_spent),
        total_available: Number(summaryData.total_available),
        unallocated: Number(summaryData.unallocated),
        is_balanced: Boolean(summaryData.is_balanced),
      },
      categories,
      suggested_period: null,
    };
  }

  /**
   * Inicializa la quincena actual con un solo tap.
   * Aplica default_income del perfil (o total_income si se envía) y copia las plantillas maestras.
   */
  async initCurrent(
    userId: string,
    dto: InitCurrentCycleDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const suggested = this.getSuggestedPeriod();

    // 1. Verificar si ya existe un ciclo para el período actual
    const { data: existingCycle } = await client
      .from('biweekly_cycles')
      .select('*')
      .eq('user_id', userId)
      .eq('year', suggested.year)
      .eq('month', suggested.month)
      .eq('period', suggested.period)
      .maybeSingle();

    if (existingCycle) {
      if (!existingCycle.is_closed) {
        return existingCycle;
      }
      throw new ConflictException(
        `El ciclo para la ${suggested.period === QuincenaPeriod.FIRST_HALF ? 'primera' : 'segunda'} quincena de ${suggested.month}/${suggested.year} ya fue cerrado.`,
      );
    }

    // 2. Determinar ingreso total (usar dto.total_income si se envió, o default_income del perfil)
    let totalIncome = dto?.total_income;
    if (totalIncome === undefined || totalIncome === null) {
      const { data: profile } = await client
        .from('profiles')
        .select('default_income')
        .eq('id', userId)
        .maybeSingle();

      totalIncome = profile?.default_income
        ? Number(profile.default_income)
        : 0;
    }

    // 3. Crear el nuevo ciclo
    const { data: newCycle, error: cycleErr } = await client
      .from('biweekly_cycles')
      .insert({
        user_id: userId,
        year: suggested.year,
        month: suggested.month,
        period: suggested.period,
        start_date: suggested.start_date,
        end_date: suggested.end_date,
        total_income: totalIncome,
        is_closed: false,
      })
      .select()
      .single();

    if (cycleErr) {
      if (cycleErr.code === '23505') {
        throw new ConflictException('Ya existe un ciclo para este período');
      }
      throw new Error(cycleErr.message);
    }

    // 4. Copiar plantillas presupuestarias maestras si existen para este período
    const { data: templates } = await client
      .from('budget_templates')
      .select('category_id, destination_account_id, default_amount')
      .eq('user_id', userId)
      .eq('period', suggested.period);

    if (templates && templates.length > 0) {
      const allocations = templates.map((tmpl) => ({
        cycle_id: newCycle.id,
        category_id: tmpl.category_id,
        destination_account_id: tmpl.destination_account_id,
        allocated_amount: tmpl.default_amount,
      }));

      await client.from('budget_allocations').insert(allocations);
    }

    return newCycle;
  }

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
