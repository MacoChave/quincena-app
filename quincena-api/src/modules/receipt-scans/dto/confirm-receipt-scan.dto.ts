import {
  IsUUID,
  IsOptional,
  IsString,
  IsNumber,
  IsDateString,
  Min,
  Max,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class ConfirmReceiptScanDto {
  @ApiPropertyOptional({
    description: 'ID del ciclo donde registrar la transacción',
  })
  @IsOptional()
  @IsUUID()
  cycle_id?: string;

  @ApiPropertyOptional({ description: 'ID de la cuenta de origen del gasto' })
  @IsOptional()
  @IsUUID()
  source_account_id?: string;

  @ApiPropertyOptional({ description: 'ID de la asignación de presupuesto' })
  @IsOptional()
  @IsUUID()
  allocation_id?: string;

  @ApiPropertyOptional({
    example: 'Walmart Zona 10',
    description: 'Nombre del comercio (corregido por usuario)',
  })
  @IsOptional()
  @IsString()
  merchant_name?: string;

  @ApiPropertyOptional({
    example: 125.5,
    description: 'Monto extraído u corregido',
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount?: number;

  @ApiPropertyOptional({
    example: '2026-10-15',
    description: 'Fecha de la transacción',
  })
  @IsOptional()
  @IsDateString()
  transaction_date?: string;

  @ApiPropertyOptional({ example: 'Compra semanal' })
  @IsOptional()
  @IsString()
  notes?: string;
}
