import {
  Controller, Get, Post, Patch, Delete, Body, Param, Query,
  ParseUUIDPipe, UseGuards, ParseBoolPipe,
} from '@nestjs/common';
import {
  ApiBearerAuth, ApiOperation, ApiTags, ApiCreatedResponse,
  ApiOkResponse, ApiQuery, ApiBody,
} from '@nestjs/swagger';
import { TransactionsService } from './transactions.service';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { UpdateTransactionDto } from './dto/update-transaction.dto';
import { SupabaseAuthGuard } from '../../common/guards/supabase-auth.guard';
import { CurrentUser, AccessToken } from '../../common/decorators/current-user.decorator';
import { User } from '@supabase/supabase-js';

@ApiTags('transactions')
@ApiBearerAuth('Supabase JWT')
@UseGuards(SupabaseAuthGuard)
@Controller('transactions')
export class TransactionsController {
  constructor(private readonly service: TransactionsService) {}

  @Get()
  @ApiOperation({ summary: 'Listar transacciones de un ciclo quincenal' })
  @ApiOkResponse({ description: 'Lista de transacciones con categorías y cuenta origen' })
  @ApiQuery({ name: 'cycleId', required: true, description: 'ID del ciclo quincenal' })
  findByCycle(
    @Query('cycleId', ParseUUIDPipe) cycleId: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
  ) {
    return this.service.findByCycle(cycleId, user.id, token);
  }

  @Post()
  @ApiOperation({
    summary: 'Registrar gasto manual con detección de duplicados (RN-03)',
    description:
      'Valida posibles duplicados por comercio+monto+fecha ±24h. ' +
      'Si detecta un duplicado, responde con HTTP 409 y `duplicate_warning: true`. ' +
      'Para forzar el registro de todas formas, enviar `?force=true`.',
  })
  @ApiCreatedResponse({ description: 'Transacción registrada' })
  @ApiQuery({
    name: 'force',
    required: false,
    type: Boolean,
    description: 'Forzar registro ignorando advertencia de duplicado (RN-03)',
  })
  create(
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: CreateTransactionDto,
    @Query('force') force?: string,
  ) {
    const forceCreate = force === 'true' || force === '1';
    return this.service.create(user.id, dto, token, forceCreate);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Editar transacción existente' })
  @ApiOkResponse({ description: 'Transacción actualizada' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: UpdateTransactionDto,
  ) {
    return this.service.update(id, user.id, dto, token);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Eliminar transacción' })
  @ApiOkResponse({ description: 'Transacción eliminada' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
  ) {
    return this.service.remove(id, user.id, token);
  }
}
