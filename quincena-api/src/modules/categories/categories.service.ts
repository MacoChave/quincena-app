import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly supabase: SupabaseService) {}

  async findAll(
    userId: string,
    accessToken: string,
    includeArchived: boolean = false,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    let query = client
      .from('categories')
      .select(
        '*, default_account:financial_accounts(id, name, color_hex, icon, account_type)',
      )
      .eq('user_id', userId);

    if (!includeArchived) {
      query = query.eq('is_archived', false);
    }

    const { data, error } = await query.order('name', { ascending: true });

    if (error) {
      throw new ConflictException(error.message);
    }

    return data;
  }

  async create(userId: string, dto: CreateCategoryDto, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    const { data, error } = await client
      .from('categories')
      .insert({ ...dto, user_id: userId })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        throw new ConflictException('Ya existe una categoría con ese nombre.');
      }
      throw new ConflictException(error.message);
    }

    return data;
  }

  async update(
    id: string,
    userId: string,
    dto: UpdateCategoryDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // Verify ownership
    const { data: existing, error: findError } = await client
      .from('categories')
      .select('id')
      .eq('id', id)
      .eq('user_id', userId)
      .single();

    if (findError || !existing) {
      throw new NotFoundException(`Categoría con id "${id}" no encontrada.`);
    }

    const { data, error } = await client
      .from('categories')
      .update(dto)
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        throw new ConflictException('Ya existe una categoría con ese nombre.');
      }
      throw new ConflictException(error.message);
    }

    return data;
  }

  async archive(id: string, userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // Verify ownership
    const { data: existing, error: findError } = await client
      .from('categories')
      .select('id')
      .eq('id', id)
      .eq('user_id', userId)
      .single();

    if (findError || !existing) {
      throw new NotFoundException(`Categoría con id "${id}" no encontrada.`);
    }

    const { data, error } = await client
      .from('categories')
      .update({ is_archived: true })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .single();

    if (error) {
      throw new ConflictException(error.message);
    }

    return data;
  }
}
