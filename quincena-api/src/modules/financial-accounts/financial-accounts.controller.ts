import {
  Controller, Get, Post, Patch, Delete, Body, Param, ParseUUIDPipe, UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags, ApiCreatedResponse, ApiOkResponse } from '@nestjs/swagger';
import { FinancialAccountsService } from './financial-accounts.service';
import { CreateFinancialAccountDto } from './dto/create-financial-account.dto';
import { UpdateFinancialAccountDto } from './dto/update-financial-account.dto';
import { SupabaseAuthGuard } from '../../common/guards/supabase-auth.guard';
import { CurrentUser, AccessToken } from '../../common/decorators/current-user.decorator';
import { User } from '@supabase/supabase-js';

@ApiTags('financial-accounts')
@ApiBearerAuth('Supabase JWT')
@UseGuards(SupabaseAuthGuard)
@Controller('financial-accounts')
export class FinancialAccountsController {
  constructor(private readonly service: FinancialAccountsService) {}

  @Get()
  @ApiOperation({ summary: 'Listar cuentas activas del usuario' })
  @ApiOkResponse({ description: 'Lista de cuentas financieras' })
  findAll(@CurrentUser() user: User, @AccessToken() token: string) {
    return this.service.findAll(user.id, token);
  }

  @Post()
  @ApiOperation({ summary: 'Crear nueva cuenta financiera' })
  @ApiCreatedResponse({ description: 'Cuenta creada exitosamente' })
  create(
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: CreateFinancialAccountDto,
  ) {
    return this.service.create(user.id, dto, token);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualizar cuenta financiera' })
  @ApiOkResponse({ description: 'Cuenta actualizada' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: UpdateFinancialAccountDto,
  ) {
    return this.service.update(id, user.id, dto, token);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Archivar cuenta financiera (soft delete)' })
  @ApiOkResponse({ description: 'Cuenta archivada' })
  archive(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
  ) {
    return this.service.archive(id, user.id, token);
  }
}
