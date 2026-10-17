import { IsUUID, IsNumber, Min, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateBudgetAllocationDto {
  @ApiProperty({ description: 'ID del ciclo quincenal' })
  @IsUUID()
  cycle_id: string;

  @ApiProperty({ description: 'ID de la categoría' })
  @IsUUID()
  category_id: string;

  @ApiPropertyOptional({ description: 'ID de la cuenta destino' })
  @IsOptional()
  @IsUUID()
  destination_account_id?: string;

  @ApiPropertyOptional({
    description: 'Alias para destination_account_id (RF-03)',
  })
  @IsOptional()
  @IsUUID()
  financial_account_id?: string;

  @ApiProperty({
    example: 800.0,
    description: 'Monto asignado a esta categoría',
  })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  allocated_amount: number;
}
