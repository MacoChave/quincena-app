import {
  IsString,
  IsOptional,
  IsNumber,
  Min,
  Length,
  IsEnum,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateProfileDto {
  @ApiPropertyOptional({
    description: 'Nombre completo del usuario',
    example: 'María García',
  })
  @IsOptional()
  @IsString()
  @Length(1, 100)
  full_name?: string;

  @ApiPropertyOptional({
    description: 'Código de moneda ISO 4217',
    example: 'GTQ',
  })
  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @ApiPropertyOptional({
    description: 'Ingreso quincenal predeterminado',
    example: 3500.0,
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  default_income?: number;
}
