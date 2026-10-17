import {
  IsUUID,
  IsNumber,
  IsString,
  IsNotEmpty,
  IsDateString,
  IsEnum,
  IsOptional,
  Length,
  Min,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { TransactionType, EntryMethod } from './create-transaction.dto';

export class UpdateTransactionDto {
  @ApiPropertyOptional({
    description: 'ID de la asignación de presupuesto (bolsa)',
  })
  @IsOptional()
  @IsUUID()
  allocation_id?: string;

  @ApiPropertyOptional({ description: 'ID de la cuenta de origen del gasto' })
  @IsOptional()
  @IsUUID()
  source_account_id?: string;

  @ApiPropertyOptional({ example: 125.5, description: 'Monto del gasto (> 0)' })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount?: number;

  @ApiPropertyOptional({
    example: 'Walmart Zona 10',
    description: 'Nombre del comercio o receptor',
  })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @Length(1, 120)
  merchant_name?: string;

  @ApiPropertyOptional({
    example: '2026-10-15',
    description: 'Fecha de la transacción (YYYY-MM-DD)',
  })
  @IsOptional()
  @IsDateString()
  transaction_date?: string;

  @ApiPropertyOptional({
    enum: TransactionType,
    default: TransactionType.EXPENSE,
  })
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
