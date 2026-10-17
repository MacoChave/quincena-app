import { IsNumber, IsOptional, IsUUID, Min } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateBudgetAllocationDto {
  @ApiPropertyOptional({
    example: 1000.0,
    description: 'Nuevo monto asignado (RN-02: rebalanceo)',
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  allocated_amount?: number;

  @ApiPropertyOptional({ description: 'Cuenta destino de este presupuesto' })
  @IsOptional()
  @IsUUID()
  destination_account_id?: string;

  @ApiPropertyOptional({
    description: 'Alias para destination_account_id (RF-03)',
  })
  @IsOptional()
  @IsUUID()
  financial_account_id?: string;
}
