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

  async findAll(userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { data, error } = await client
      .from('financial_accounts')
      .select('*')
      .eq('user_id', userId)
      .eq('is_archived', false)
      .order('is_default', { ascending: false })
      .order('name');

    if (error) throw new Error(error.message);
    return data;
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

    const { data, error } = await client
      .from('financial_accounts')
      .insert({ ...dto, user_id: userId })
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
    return data;
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
    return data;
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
}
