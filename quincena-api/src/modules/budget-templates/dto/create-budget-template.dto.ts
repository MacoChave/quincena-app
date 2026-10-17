import { IsEnum, IsUUID, IsNumber, Min, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum QuincenaPeriod {
  FIRST_HALF = 'first_half',
  SECOND_HALF = 'second_half',
}

export class CreateBudgetTemplateDto {
  @ApiProperty({ enum: QuincenaPeriod, example: QuincenaPeriod.FIRST_HALF })
  @IsEnum(QuincenaPeriod)
  period: QuincenaPeriod;

  @ApiProperty({ example: 'uuid-categoria' })
  @IsUUID()
  category_id: string;

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

  @ApiProperty({ example: 500.0 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  default_amount: number;
}
