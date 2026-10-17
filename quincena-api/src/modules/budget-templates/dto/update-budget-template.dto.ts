import { IsNumber, Min, IsOptional, IsUUID } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateBudgetTemplateDto {
  @ApiPropertyOptional({ example: 600.0 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  default_amount?: number;

  @ApiPropertyOptional({ example: 'uuid-cuenta' })
  @IsOptional()
  @IsUUID()
  destination_account_id?: string;

  @ApiPropertyOptional({
    example: 'uuid-cuenta',
    description: 'Alias para destination_account_id (RF-03)',
  })
  @IsOptional()
  @IsUUID()
  financial_account_id?: string;
}
