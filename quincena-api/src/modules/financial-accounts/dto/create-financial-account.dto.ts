import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsBoolean,
  IsEnum,
  IsNumber,
  Min,
  Length,
  Matches,
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
  @ApiProperty({
    example: 'Banco Industrial',
    description: 'Nombre de la cuenta',
  })
  @IsString()
  @IsNotEmpty()
  @Length(1, 80)
  name: string;

  @ApiProperty({ enum: AccountType, example: AccountType.CHECKING })
  @IsEnum(AccountType)
  account_type: AccountType;

  @ApiPropertyOptional({
    example: 'GTQ',
    description: 'Código de moneda ISO 4217',
  })
  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @ApiPropertyOptional({
    example: '#79ADDC',
    description: 'Color hex de la cuenta',
  })
  @IsOptional()
  @IsString()
  @Matches(/^#[0-9A-Fa-f]{6}$/, {
    message: 'color_hex debe ser un código hexadecimal válido (#RRGGBB)',
  })
  color_hex?: string;

  @ApiPropertyOptional({
    example: 'account_balance',
    description: 'Nombre del icono (Material Icons / Stitch)',
  })
  @IsOptional()
  @IsString()
  @Length(1, 50)
  icon?: string;

  @ApiPropertyOptional({
    example: 1500.0,
    description: 'Saldo inicial de la cuenta',
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0, { message: 'El saldo inicial no puede ser negativo' })
  initial_balance?: number;

  @ApiPropertyOptional({
    example: false,
    description: '¿Es la cuenta predeterminada?',
  })
  @IsOptional()
  @IsBoolean()
  is_default?: boolean;
}
