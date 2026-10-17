import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  ParseUUIDPipe,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiConsumes,
  ApiBody,
} from '@nestjs/swagger';
import { ReceiptScansService } from './receipt-scans.service';
import { ConfirmReceiptScanDto } from './dto/confirm-receipt-scan.dto';
import { SupabaseAuthGuard } from '../../common/guards/supabase-auth.guard';
import {
  CurrentUser,
  AccessToken,
} from '../../common/decorators/current-user.decorator';
import { User } from '@supabase/supabase-js';

@ApiTags('receipt-scans')
@ApiBearerAuth('Supabase JWT')
@UseGuards(SupabaseAuthGuard)
@Controller('receipt-scans')
export class ReceiptScansController {
  constructor(private readonly service: ReceiptScansService) {}

  @Get()
  @ApiOperation({ summary: 'Listar comprobantes recientes del usuario' })
  @ApiOkResponse({ description: 'Lista de comprobantes OCR' })
  findAll(@CurrentUser() user: User, @AccessToken() token: string) {
    return this.service.findAllByUser(user.id, token);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener comprobante OCR y datos extraídos' })
  @ApiOkResponse({ description: 'Comprobante con datos OCR extraídos' })
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
  ) {
    return this.service.findOne(id, user.id, token);
  }

  @Post('upload')
  @ApiOperation({
    summary: 'Subir imagen/PDF de comprobante para procesamiento OCR (RF-03)',
    description:
      'Acepta imágenes (JPG, PNG) y documentos PDF. ' +
      'El archivo se sube a Supabase Storage y se inicia el procesamiento OCR.',
  })
  @ApiCreatedResponse({ description: 'Comprobante subido, OCR en proceso' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  @UseInterceptors(FileInterceptor('file'))
  upload(
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.service.uploadAndCreateScan(user.id, file, token);
  }

  @Post(':id/confirm')
  @ApiOperation({
    summary: 'Confirmar datos OCR y crear transacción (CA-03.2)',
    description:
      'El usuario valida o corrige los campos extraídos (monto, comercio, fecha) ' +
      'antes de confirmar el registro del gasto. Nunca se guarda de forma ciega.',
  })
  @ApiCreatedResponse({ description: 'Gasto confirmado y registrado' })
  confirm(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
    @AccessToken() token: string,
    @Body() dto: ConfirmReceiptScanDto,
  ) {
    return this.service.confirmAndCreateTransaction(id, user.id, dto, token);
  }
}
