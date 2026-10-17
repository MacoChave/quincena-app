import {
  IsEmail,
  IsNotEmpty,
  IsString,
  MinLength,
  Matches,
  IsOptional,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RegisterDto {
  @ApiProperty({
    example: 'usuario@correo.com',
    description: 'Correo electrónico válido',
  })
  @IsEmail(
    {},
    { message: 'El correo electrónico debe tener un formato válido' },
  )
  @IsNotEmpty()
  email: string;

  @ApiProperty({
    example: 'Quincena2026!',
    description:
      'Contraseña mínima de 8 caracteres, al menos 1 mayúscula, 1 minúscula y 1 número (CA-A1.2)',
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(8, { message: 'La contraseña debe tener al menos 8 caracteres' })
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, {
    message:
      'La contraseña debe contener al menos una letra mayúscula, una minúscula y un dígito numérico',
  })
  password: string;

  @ApiPropertyOptional({
    example: 'Juan Pérez',
    description: 'Nombre completo del usuario',
  })
  @IsOptional()
  @IsString()
  full_name?: string;
}
