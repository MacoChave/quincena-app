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
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiQuery,
} from '@nestjs/swagger';
import { BudgetAllocationsService } from './budget-allocations.service';
import { CreateBudgetAllocationDto } from './dto/create-budget-allocation.dto';
import { UpdateBudgetAllocationDto } from './dto/update-budget-allocation.dto';
import { SupabaseAuthGuard } from '../../common/guards/supabase-auth.guard';
import {
  CurrentUser,
  AccessToken,
} from '../../common/decorators/current-user.decorator';
import { User } from '@supabase/supabase-js';

@ApiTags('budget-allocations')
@ApiBearerAuth('Supabase JWT')
@UseGuards(SupabaseAuthGuard)
@Controller('budget-allocations')
export class BudgetAllocationsController {
  constructor(private readonly service: BudgetAllocationsService) {}

  @Get()
  @ApiOperation({
    summary:
      'Obtener asignaciones de un ciclo con saldo disponible y "Por Asignar" (CA-02.1)',
  })
  @ApiOkResponse({
    description: 'Asignaciones del ciclo con resumen financiero',
  })
  @ApiQuery({
    name: 'cycleId',
    required: true,
    description: 'ID del ciclo quincenal',
  })
  findByCycle(
    @Query('cycleId', ParseUUIDPipe) cycleId: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
  ) {
    return this.service.findByCycle(cycleId, user.id, token);
  }

  @Post()
  @ApiOperation({ summary: 'Crear asignación de presupuesto en un ciclo' })
  @ApiCreatedResponse({ description: 'Asignación creada' })
  create(
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: CreateBudgetAllocationDto,
  ) {
    return this.service.create(user.id, dto, token);
  }

  @Patch(':id')
  @ApiOperation({
    summary:
      'Actualizar monto de asignación (RN-02: rebalanceo inter-categorías)',
  })
  @ApiOkResponse({ description: 'Asignación actualizada' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: UpdateBudgetAllocationDto,
  ) {
    return this.service.update(id, user.id, dto, token);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Eliminar asignación de presupuesto' })
  @ApiOkResponse({ description: 'Asignación eliminada' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
  ) {
    return this.service.remove(id, user.id, token);
  }
}
