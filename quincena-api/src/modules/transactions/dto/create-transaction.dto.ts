import {
  IsUUID, IsNumber, IsString, IsNotEmpty, IsDateString,
  IsEnum, IsOptional, Length, Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum TransactionType {
  EXPENSE = 'expense',
  INCOME_ADJUSTMENT = 'income_adjustment',
  TRANSFER = 'transfer',
}

export enum EntryMethod {
  MANUAL = 'manual',
  OCR = 'ocr',
}

export class CreateTransactionDto {
  @ApiProperty({ description: 'ID del ciclo quincenal' })
  @IsUUID()
  cycle_id: string;

  @ApiPropertyOptional({ description: 'ID de la asignación de presupuesto (bolsa)' })
  @IsOptional()
  @IsUUID()
  allocation_id?: string;

  @ApiPropertyOptional({ description: 'ID del comprobante OCR origen' })
  @IsOptional()
  @IsUUID()
  receipt_scan_id?: string;

  @ApiProperty({ description: 'ID de la cuenta de origen del gasto' })
  @IsUUID()
  source_account_id: string;

  @ApiProperty({ example: 125.50, description: 'Monto del gasto (> 0)' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @ApiProperty({ example: 'Walmart Zona 10', description: 'Nombre del comercio o receptor' })
  @IsString()
  @IsNotEmpty()
  @Length(1, 120)
  merchant_name: string;

  @ApiProperty({ example: '2026-10-15', description: 'Fecha de la transacción (YYYY-MM-DD)' })
  @IsDateString()
  transaction_date: string;

  @ApiPropertyOptional({ enum: TransactionType, default: TransactionType.EXPENSE })
  @IsOptional()
  @IsEnum(TransactionType)
  transaction_type?: TransactionType;

  @ApiPropertyOptional({ enum: EntryMethod, default: EntryMethod.MANUAL })
  @IsOptional()
  @IsEnum(EntryMethod)
  entry_method?: EntryMethod;

  @ApiPropertyOptional({ example: 'Compra mensual de víveres' })
  @IsOptional()
  @IsString()
  notes?: string;
}
