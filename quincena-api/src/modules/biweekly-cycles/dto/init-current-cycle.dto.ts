import { IsNumber, IsOptional, Min } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class InitCurrentCycleDto {
  @ApiPropertyOptional({
    example: 7000.0,
    description:
      'Ingreso total para la quincena. Si no se envía o es nulo, se toma default_income del perfil del usuario.',
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  total_income?: number;
}
