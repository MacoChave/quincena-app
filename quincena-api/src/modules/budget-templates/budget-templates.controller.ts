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
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { BudgetTemplatesService } from './budget-templates.service';
import { CreateBudgetTemplateDto, QuincenaPeriod } from './dto/create-budget-template.dto';
import { UpdateBudgetTemplateDto } from './dto/update-budget-template.dto';

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
  @ApiResponse({ status: 200, description: 'List of budget templates with category details' })
  findByPeriod(
    @CurrentUser() user: User,
    @Query('period') period: QuincenaPeriod,
    @CurrentUser('accessToken') accessToken: string,
  ) {
    return this.budgetTemplatesService.findByPeriod(
      user.id,
      period,
      accessToken,
    );
  }

  @Post()
  @ApiOperation({ summary: 'Create a new budget template' })
  @ApiResponse({ status: 201, description: 'Budget template created successfully' })
  @ApiResponse({ status: 409, description: 'Template already exists for this category and period' })
  create(
    @CurrentUser() user: User,
    @Body() dto: CreateBudgetTemplateDto,
    @CurrentUser('accessToken') accessToken: string,
  ) {
    return this.budgetTemplatesService.create(user.id, dto, accessToken);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a budget template' })
  @ApiResponse({ status: 200, description: 'Budget template updated successfully' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @Body() dto: UpdateBudgetTemplateDto,
    @CurrentUser('accessToken') accessToken: string,
  ) {
    return this.budgetTemplatesService.update(id, user.id, dto, accessToken);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a budget template' })
  @ApiResponse({ status: 200, description: 'Budget template deleted successfully' })
  @ApiResponse({ status: 404, description: 'Budget template not found' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @CurrentUser('accessToken') accessToken: string,
  ) {
    return this.budgetTemplatesService.remove(id, user.id, accessToken);
  }
}
