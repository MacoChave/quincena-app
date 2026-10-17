import { IsNumber, IsOptional, IsUUID, Min } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateBiweeklyCycleDto {
  @ApiPropertyOptional({
    example: 7500.0,
    description: 'Ingreso total actualizado',
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  total_income?: number;

  @ApiPropertyOptional({ description: 'ID de la cuenta destino del ingreso' })
  @IsOptional()
  @IsUUID()
  income_destination_account_id?: string;
}
