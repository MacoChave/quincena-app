import {
  IsEnum,
  IsInt,
  IsString,
  IsOptional,
  IsUUID,
  IsNumber,
  IsBoolean,
  Min,
  Max,
  IsDateString,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum QuincenaPeriod {
  FIRST_HALF = 'first_half',
  SECOND_HALF = 'second_half',
}

export class CreateBiweeklyCycleDto {
  @ApiProperty({ example: 2026, description: 'Año del ciclo' })
  @IsInt()
  @Min(2024)
  @Max(2100)
  year: number;

  @ApiProperty({ example: 10, description: 'Mes del ciclo (1-12)' })
  @IsInt()
  @Min(1)
  @Max(12)
  month: number;

  @ApiProperty({ enum: QuincenaPeriod, example: QuincenaPeriod.FIRST_HALF })
  @IsEnum(QuincenaPeriod)
  period: QuincenaPeriod;

  @ApiProperty({
    example: '2026-10-01',
    description: 'Fecha de inicio (YYYY-MM-DD)',
  })
  @IsDateString()
  start_date: string;

  @ApiProperty({
    example: '2026-10-15',
    description: 'Fecha de fin (YYYY-MM-DD)',
  })
  @IsDateString()
  end_date: string;

  @ApiProperty({ example: 7000.0, description: 'Ingreso total de la quincena' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  total_income: number;

  @ApiPropertyOptional({
    description: 'ID de la cuenta de destino del ingreso',
  })
  @IsOptional()
  @IsUUID()
  income_destination_account_id?: string;
}
