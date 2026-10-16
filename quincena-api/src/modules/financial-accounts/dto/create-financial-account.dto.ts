import {
  IsString, IsNotEmpty, IsOptional, IsBoolean, IsEnum, Length, Matches,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum AccountType {
  CHECKING = 'checking',
  SAVINGS = 'savings',
  CASH = 'cash',
  CREDIT_CARD = 'credit_card',
  DIGITAL_WALLET = 'digital_wallet',
}

export class CreateFinancialAccountDto {
  @ApiProperty({ example: 'Banco Industrial', description: 'Nombre de la cuenta' })
  @IsString()
  @IsNotEmpty()
  @Length(1, 80)
  name: string;

  @ApiProperty({ enum: AccountType, example: AccountType.CHECKING })
  @IsEnum(AccountType)
  account_type: AccountType;

  @ApiPropertyOptional({ example: 'GTQ', description: 'Código de moneda ISO 4217' })
  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @ApiPropertyOptional({ example: '#79ADDC', description: 'Color hex de la cuenta' })
  @IsOptional()
  @IsString()
  @Matches(/^#[0-9A-Fa-f]{6}$/, { message: 'color_hex debe ser un código hexadecimal válido (#RRGGBB)' })
  color_hex?: string;

  @ApiPropertyOptional({ example: false, description: '¿Es la cuenta predeterminada?' })
  @IsOptional()
  @IsBoolean()
  is_default?: boolean;
}
