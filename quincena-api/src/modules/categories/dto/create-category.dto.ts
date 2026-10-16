import { IsString, IsNotEmpty, IsOptional, IsUUID, Length, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateCategoryDto {
  @ApiProperty({ example: 'Supermercado' })
  @IsString()
  @IsNotEmpty()
  @Length(1, 60)
  name: string;

  @ApiPropertyOptional({ example: 'shopping-cart' })
  @IsOptional()
  @IsString()
  @Length(1, 50)
  icon?: string;

  @ApiPropertyOptional({ example: '#79ADDC' })
  @IsOptional()
  @IsString()
  @Matches(/^#[0-9A-Fa-f]{6}$/, { message: 'color_hex debe ser un código hexadecimal válido (#RRGGBB)' })
  color_hex?: string;

  @ApiPropertyOptional({ example: 'uuid-de-cuenta' })
  @IsOptional()
  @IsUUID()
  default_account_id?: string;
}
