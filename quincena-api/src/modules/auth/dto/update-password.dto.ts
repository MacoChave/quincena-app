import { IsOptional, IsString, MinLength, Matches } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdatePasswordDto {
  @ApiPropertyOptional({
    example: 'PasswordActual123!',
    description:
      'Contraseña actual del usuario (opcional en reset por deep link; validada si se proporciona desde Ajustes)',
  })
  @IsOptional()
  @IsString()
  current_password?: string;

  @ApiPropertyOptional({
    example: 'NuevaPassword2026!',
    description:
      'Nueva contraseña: mín 8 caracteres, 1 mayúscula, 1 minúscula y 1 número (CA-A1.2, CA-A2.4)',
  })
  @IsOptional()
  @IsString()
  @MinLength(8, {
    message: 'La nueva contraseña debe tener al menos 8 caracteres',
  })
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, {
    message:
      'La nueva contraseña debe contener al menos una letra mayúscula, una minúscula y un dígito numérico',
  })
  password?: string;

  @ApiPropertyOptional({
    example: 'NuevaPassword2026!',
    description:
      'Alias para new_password enviado por clientes móviles (mín 8 caracteres, 1 mayús, 1 minús, 1 núm)',
  })
  @IsOptional()
  @IsString()
  @MinLength(8, {
    message: 'La nueva contraseña debe tener al menos 8 caracteres',
  })
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, {
    message:
      'La nueva contraseña debe contener al menos una letra mayúscula, una minúscula y un dígito numérico',
  })
  new_password?: string;
}
