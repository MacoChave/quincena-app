import {
  Controller, Get, Post, Patch, Body, Param, ParseUUIDPipe, UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth, ApiOperation, ApiTags, ApiCreatedResponse, ApiOkResponse,
} from '@nestjs/swagger';
import { BiweeklyCyclesService } from './biweekly-cycles.service';
import { CreateBiweeklyCycleDto } from './dto/create-biweekly-cycle.dto';
import { UpdateBiweeklyCycleDto } from './dto/update-biweekly-cycle.dto';
import { CloseCycleDto } from './dto/close-cycle.dto';
import { SupabaseAuthGuard } from '../../common/guards/supabase-auth.guard';
import { CurrentUser, AccessToken } from '../../common/decorators/current-user.decorator';
import { User } from '@supabase/supabase-js';

@ApiTags('biweekly-cycles')
@ApiBearerAuth('Supabase JWT')
@UseGuards(SupabaseAuthGuard)
@Controller('biweekly-cycles')
export class BiweeklyCyclesController {
  constructor(private readonly service: BiweeklyCyclesService) {}

  @Get()
  @ApiOperation({ summary: 'Listar todos los ciclos quincenales del usuario' })
  @ApiOkResponse({ description: 'Lista de ciclos' })
  findAll(@CurrentUser() user: User, @AccessToken() token: string) {
    return this.service.findAll(user.id, token);
  }

  @Get('current')
  @ApiOperation({ summary: 'Obtener el ciclo quincenal activo actual' })
  @ApiOkResponse({ description: 'Ciclo activo' })
  findCurrent(@CurrentUser() user: User, @AccessToken() token: string) {
    return this.service.findCurrent(user.id, token);
  }

  @Post()
  @ApiOperation({ summary: 'Crear nuevo ciclo quincenal' })
  @ApiCreatedResponse({ description: 'Ciclo creado' })
  create(
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: CreateBiweeklyCycleDto,
  ) {
    return this.service.create(user.id, dto, token);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualizar ingreso del ciclo (solo ciclos abiertos)' })
  @ApiOkResponse({ description: 'Ciclo actualizado' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: UpdateBiweeklyCycleDto,
  ) {
    return this.service.update(id, user.id, dto, token);
  }

  @Post(':id/close')
  @ApiOperation({
    summary: 'Cerrar ciclo quincenal con gestión de remanente (CA-01.2)',
    description:
      'Congela el ciclo y procesa el saldo remanente según la acción elegida: ' +
      'sumar al nuevo ciclo, transferir a ahorro, o archivar.',
  })
  @ApiOkResponse({ description: 'Ciclo cerrado con resumen de remanente' })
  close(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: CloseCycleDto,
  ) {
    return this.service.close(id, user.id, dto, token);
  }
}
