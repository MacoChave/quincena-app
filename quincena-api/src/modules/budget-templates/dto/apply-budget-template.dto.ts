import { IsUUID, IsOptional, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ApplyBudgetTemplateDto {
  @ApiProperty({
    example: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    description:
      'ID del ciclo quincenal al que se aplicará la plantilla maestra',
  })
  @IsUUID()
  cycle_id: string;

  @ApiPropertyOptional({
    example: false,
    description:
      'Indica si se deben sobreescribir las asignaciones existentes en el ciclo',
    default: false,
  })
  @IsOptional()
  @IsBoolean()
  overwrite?: boolean;
}
