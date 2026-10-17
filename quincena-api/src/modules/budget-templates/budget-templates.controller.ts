import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  ParseUUIDPipe,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
} from '@nestjs/swagger';
import { User } from '@supabase/supabase-js';

import { SupabaseAuthGuard } from '../../common/guards/supabase-auth.guard';
import {
  CurrentUser,
  AccessToken,
} from '../../common/decorators/current-user.decorator';
import { BudgetTemplatesService } from './budget-templates.service';
import {
  CreateBudgetTemplateDto,
  QuincenaPeriod,
} from './dto/create-budget-template.dto';
import { UpdateBudgetTemplateDto } from './dto/update-budget-template.dto';
import { ApplyBudgetTemplateDto } from './dto/apply-budget-template.dto';
import { SaveFromCycleDto } from './dto/save-from-cycle.dto';

@ApiTags('budget-templates')
@ApiBearerAuth('Supabase JWT')
@UseGuards(SupabaseAuthGuard)
@Controller('budget-templates')
export class BudgetTemplatesController {
  constructor(
    private readonly budgetTemplatesService: BudgetTemplatesService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Get budget templates for a given period' })
  @ApiResponse({
    status: 200,
    description: 'List of budget templates with category details',
  })
  findByPeriod(
    @CurrentUser() user: User,
    @Query('period') period: QuincenaPeriod,
    @AccessToken() token: string,
  ) {
    return this.budgetTemplatesService.findByPeriod(user.id, period, token);
  }

  @Post()
  @ApiOperation({ summary: 'Create a new budget template' })
  @ApiResponse({
    status: 201,
    description: 'Budget template created successfully',
  })
  @ApiResponse({
    status: 409,
    description: 'Template already exists for this category and period',
  })
  create(
    @CurrentUser() user: User,
    @Body() dto: CreateBudgetTemplateDto,
    @AccessToken() token: string,
  ) {
    return this.budgetTemplatesService.create(user.id, dto, token);
  }

  @Post('apply')
  @ApiOperation({
    summary: 'Aplicar plantilla predefinida al ciclo activo (RF-04)',
  })
  @ApiResponse({
    status: 201,
    description: 'Plantilla aplicada exitosamente al ciclo',
  })
  @ApiResponse({ status: 400, description: 'Ciclo cerrado o datos inválidos' })
  @ApiResponse({ status: 404, description: 'Ciclo no encontrado' })
  @ApiResponse({
    status: 409,
    description:
      'El ciclo ya posee asignaciones y no se especificó overwrite: true',
  })
  apply(
    @CurrentUser() user: User,
    @Body() dto: ApplyBudgetTemplateDto,
    @AccessToken() token: string,
  ) {
    return this.budgetTemplatesService.apply(user.id, dto, token);
  }

  @Post('save-from-cycle')
  @ApiOperation({
    summary:
      'Guardar asignaciones del ciclo activo como plantilla maestra (RF-04)',
  })
  @ApiResponse({
    status: 201,
    description: 'Plantilla actualizada exitosamente a partir del ciclo',
  })
  @ApiResponse({ status: 400, description: 'El ciclo no posee asignaciones' })
  @ApiResponse({ status: 404, description: 'Ciclo no encontrado' })
  saveFromCycle(
    @CurrentUser() user: User,
    @Body() dto: SaveFromCycleDto,
    @AccessToken() token: string,
  ) {
    return this.budgetTemplatesService.saveFromCycle(user.id, dto, token);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a budget template' })
  @ApiResponse({
    status: 200,
    description: 'Budget template updated successfully',
  })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @Body() dto: UpdateBudgetTemplateDto,
    @AccessToken() token: string,
  ) {
    return this.budgetTemplatesService.update(id, user.id, dto, token);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a budget template' })
  @ApiResponse({
    status: 200,
    description: 'Budget template deleted successfully',
  })
  @ApiResponse({ status: 404, description: 'Budget template not found' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
  ) {
    return this.budgetTemplatesService.remove(id, user.id, token);
  }
}
