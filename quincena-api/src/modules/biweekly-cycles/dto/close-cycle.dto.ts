import { IsEnum, IsOptional, IsUUID, IsNumber, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum RolloverAction {
  ADD_TO_NEW_CYCLE = 'add_to_new_cycle',
  TRANSFER_TO_SAVINGS = 'transfer_to_savings',
  ARCHIVE = 'archive',
}

export class CloseCycleDto {
  @ApiProperty({
    enum: RolloverAction,
    example: RolloverAction.ADD_TO_NEW_CYCLE,
    description: 'Acción a tomar con el remanente al cerrar el ciclo (CA-01.2)',
  })
  @IsEnum(RolloverAction)
  rollover_action: RolloverAction;

  @ApiPropertyOptional({
    description:
      'ID de cuenta de ahorro destino (requerido si rollover_action=transfer_to_savings)',
  })
  @IsOptional()
  @IsUUID()
  savings_account_id?: string;
}
