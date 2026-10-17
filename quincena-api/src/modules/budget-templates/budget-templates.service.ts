import {
  Injectable,
  ConflictException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { SupabaseService } from '../../supabase/supabase.service';
import { BudgetAllocationsService } from '../budget-allocations/budget-allocations.service';
import {
  CreateBudgetTemplateDto,
  QuincenaPeriod,
} from './dto/create-budget-template.dto';
import { UpdateBudgetTemplateDto } from './dto/update-budget-template.dto';
import { ApplyBudgetTemplateDto } from './dto/apply-budget-template.dto';
import { SaveFromCycleDto } from './dto/save-from-cycle.dto';

@Injectable()
export class BudgetTemplatesService {
  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly budgetAllocationsService: BudgetAllocationsService,
  ) {}

  private getClient(accessToken: string): SupabaseClient {
    return this.supabaseService.getAuthenticatedClient(accessToken);
  }

  async findByPeriod(
    userId: string,
    period: QuincenaPeriod,
    accessToken: string,
  ) {
    const client = this.getClient(accessToken);

    const { data, error } = await client
      .from('budget_templates')
      .select(
        '*, categories(id, name, icon, color_hex), destination_account:financial_accounts(id, name, color_hex, icon)',
      )
      .eq('user_id', userId)
      .eq('period', period)
      .order('name', { referencedTable: 'categories', ascending: true });

    if (error) {
      throw new Error(error.message);
    }

    return data;
  }

  async create(
    userId: string,
    dto: CreateBudgetTemplateDto,
    accessToken: string,
  ) {
    const client = this.getClient(accessToken);
    const destinationAccountId =
      dto.destination_account_id !== undefined
        ? dto.destination_account_id
        : (dto.financial_account_id ?? null);

    const { data, error } = await client
      .from('budget_templates')
      .insert({
        user_id: userId,
        period: dto.period,
        category_id: dto.category_id,
        destination_account_id: destinationAccountId,
        default_amount: dto.default_amount,
      })
      .select(
        '*, categories(id, name, icon, color_hex), destination_account:financial_accounts(id, name, color_hex, icon)',
      )
      .single();

    if (error) {
      if (error.code === '23505') {
        throw new ConflictException(
          'Ya existe una plantilla para esta categoría en este período',
        );
      }
      throw new Error(error.message);
    }

    return data;
  }

  async update(
    id: string,
    userId: string,
    dto: UpdateBudgetTemplateDto,
    accessToken: string,
  ) {
    const client = this.getClient(accessToken);
    const destinationAccountId =
      dto.destination_account_id !== undefined
        ? dto.destination_account_id
        : dto.financial_account_id;

    const updatePayload: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };
    if (dto.default_amount !== undefined) {
      updatePayload.default_amount = dto.default_amount;
    }
    if (destinationAccountId !== undefined) {
      updatePayload.destination_account_id = destinationAccountId;
    }

    const { data, error } = await client
      .from('budget_templates')
      .update(updatePayload)
      .eq('id', id)
      .eq('user_id', userId)
      .select(
        '*, categories(id, name, icon, color_hex), destination_account:financial_accounts(id, name, color_hex, icon)',
      )
      .single();

    if (error) {
      throw new Error(error.message);
    }

    if (!data) {
      throw new NotFoundException(`Plantilla con id ${id} no encontrada`);
    }

    return data;
  }

  async remove(id: string, userId: string, accessToken: string) {
    const client = this.getClient(accessToken);

    const { data, error } = await client
      .from('budget_templates')
      .delete()
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .single();

    if (error) {
      throw new Error(error.message);
    }

    if (!data) {
      throw new NotFoundException(`Plantilla con id ${id} no encontrada`);
    }

    return data;
  }

  /**
   * Aplica la plantilla presupuestaria correspondiente al período del ciclo.
   * Si existen asignaciones previas y overwrite es false, retorna 409 Conflict.
   * Si overwrite es true, limpia asignaciones existentes y precarga las de la plantilla.
   */
  async apply(
    userId: string,
    dto: ApplyBudgetTemplateDto,
    accessToken: string,
  ) {
    const client = this.getClient(accessToken);

    // 1. Verificar existencia y pertenencia del ciclo
    const { data: cycle, error: cycleErr } = await client
      .from('biweekly_cycles')
      .select('id, period, is_closed, user_id')
      .eq('id', dto.cycle_id)
      .eq('user_id', userId)
      .single();

    if (cycleErr || !cycle) {
      throw new NotFoundException('Ciclo no encontrado');
    }

    if (cycle.is_closed) {
      throw new BadRequestException(
        'No se puede aplicar plantilla a un ciclo cerrado (RN-01)',
      );
    }

    // 2. Verificar si el ciclo ya posee asignaciones previas
    const { data: existingAllocations, error: checkErr } = await client
      .from('budget_allocations')
      .select('id')
      .eq('cycle_id', dto.cycle_id);

    if (checkErr) {
      throw new Error(checkErr.message);
    }

    if (existingAllocations && existingAllocations.length > 0) {
      if (!dto.overwrite) {
        throw new ConflictException(
          'El ciclo ya posee asignaciones presupuestarias. Utilice overwrite: true para reemplazarlas.',
        );
      }
      // Overwrite activado: limpiar asignaciones existentes del ciclo
      const { error: deleteErr } = await client
        .from('budget_allocations')
        .delete()
        .eq('cycle_id', dto.cycle_id);

      if (deleteErr) {
        throw new Error(deleteErr.message);
      }
    }

    // 3. Obtener plantillas maestras configuradas para el período del ciclo
    const { data: templates, error: tmplErr } = await client
      .from('budget_templates')
      .select('category_id, destination_account_id, default_amount')
      .eq('user_id', userId)
      .eq('period', cycle.period);

    if (tmplErr) {
      throw new Error(tmplErr.message);
    }

    // 4. Insertar las asignaciones basadas en la plantilla
    if (templates && templates.length > 0) {
      const allocationsToInsert = templates.map((tmpl) => ({
        cycle_id: cycle.id,
        category_id: tmpl.category_id,
        destination_account_id: tmpl.destination_account_id,
        allocated_amount: tmpl.default_amount,
      }));

      const { error: insertErr } = await client
        .from('budget_allocations')
        .insert(allocationsToInsert);

      if (insertErr) {
        throw new Error(insertErr.message);
      }
    }

    // 5. Retornar asignaciones enriquecidas con gasto y resumen financiero
    return this.budgetAllocationsService.findByCycle(
      cycle.id,
      userId,
      accessToken,
    );
  }

  /**
   * Guarda las asignaciones actuales de un ciclo como plantilla maestra para ese período.
   * Utiliza upsert sobre (user_id, period, category_id) sin alterar ciclos históricos.
   */
  async saveFromCycle(
    userId: string,
    dto: SaveFromCycleDto,
    accessToken: string,
  ) {
    const client = this.getClient(accessToken);

    // 1. Verificar existencia y pertenencia del ciclo
    const { data: cycle, error: cycleErr } = await client
      .from('biweekly_cycles')
      .select('id, period, user_id')
      .eq('id', dto.cycle_id)
      .eq('user_id', userId)
      .single();

    if (cycleErr || !cycle) {
      throw new NotFoundException('Ciclo no encontrado');
    }

    // 2. Obtener asignaciones actuales del ciclo
    const { data: allocations, error: allocErr } = await client
      .from('budget_allocations')
      .select('category_id, destination_account_id, allocated_amount')
      .eq('cycle_id', dto.cycle_id);

    if (allocErr) {
      throw new Error(allocErr.message);
    }

    if (!allocations || allocations.length === 0) {
      throw new BadRequestException(
        'El ciclo no posee asignaciones para guardar como plantilla',
      );
    }

    // 3. Preparar filas para upsert en budget_templates
    const templateRows = allocations.map((alloc) => ({
      user_id: userId,
      period: cycle.period,
      category_id: alloc.category_id,
      destination_account_id: alloc.destination_account_id,
      default_amount: alloc.allocated_amount,
      updated_at: new Date().toISOString(),
    }));

    // 4. Ejecutar upsert según la restricción UNIQUE (user_id, period, category_id)
    const { data: savedTemplates, error: upsertErr } = await client
      .from('budget_templates')
      .upsert(templateRows, { onConflict: 'user_id,period,category_id' })
      .select(
        '*, categories(id, name, icon, color_hex), destination_account:financial_accounts(id, name, color_hex, icon)',
      );

    if (upsertErr) {
      throw new Error(upsertErr.message);
    }

    return savedTemplates;
  }
}
