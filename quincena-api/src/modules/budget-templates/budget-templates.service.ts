import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { SupabaseService } from '../../supabase/supabase.service';
import { CreateBudgetTemplateDto, QuincenaPeriod } from './dto/create-budget-template.dto';
import { UpdateBudgetTemplateDto } from './dto/update-budget-template.dto';

@Injectable()
export class BudgetTemplatesService {
  constructor(private readonly supabaseService: SupabaseService) {}

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
      .select('*, categories(id, name, icon, color_hex)')
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

    const { data, error } = await client
      .from('budget_templates')
      .insert({
        user_id: userId,
        period: dto.period,
        category_id: dto.category_id,
        destination_account_id: dto.destination_account_id ?? null,
        default_amount: dto.default_amount,
      })
      .select('*, categories(id, name, icon, color_hex)')
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

    const { data, error } = await client
      .from('budget_templates')
      .update({
        ...(dto.default_amount !== undefined && {
          default_amount: dto.default_amount,
        }),
        ...(dto.destination_account_id !== undefined && {
          destination_account_id: dto.destination_account_id,
        }),
      })
      .eq('id', id)
      .eq('user_id', userId)
      .select('*, categories(id, name, icon, color_hex)')
      .single();

    if (error) {
      throw new Error(error.message);
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
      throw new NotFoundException(
        `Plantilla con id ${id} no encontrada`,
      );
    }

    return data;
  }
}
