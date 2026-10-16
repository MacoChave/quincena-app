import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  ParseUUIDPipe,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
  ApiCreatedResponse,
  ApiOkResponse,
} from '@nestjs/swagger';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { SupabaseAuthGuard } from '../../common/guards/supabase-auth.guard';
import { CurrentUser, AccessToken } from '../../common/decorators/current-user.decorator';
import { User } from '@supabase/supabase-js';

@ApiTags('categories')
@ApiBearerAuth('Supabase JWT')
@UseGuards(SupabaseAuthGuard)
@Controller('categories')
export class CategoriesController {
  constructor(private readonly service: CategoriesService) {}

  @Get()
  @ApiOperation({ summary: 'Listar categorías activas del usuario' })
  @ApiOkResponse({ description: 'Lista de categorías' })
  findAll(@CurrentUser() user: User, @AccessToken() token: string) {
    return this.service.findAll(user.id, token);
  }

  @Post()
  @ApiOperation({ summary: 'Crear nueva categoría' })
  @ApiCreatedResponse({ description: 'Categoría creada exitosamente' })
  create(
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: CreateCategoryDto,
  ) {
    return this.service.create(user.id, dto, token);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualizar categoría' })
  @ApiOkResponse({ description: 'Categoría actualizada' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: UpdateCategoryDto,
  ) {
    return this.service.update(id, user.id, dto, token);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Archivar categoría (soft delete)' })
  @ApiOkResponse({ description: 'Categoría archivada' })
  archive(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
  ) {
    return this.service.archive(id, user.id, token);
  }
}
