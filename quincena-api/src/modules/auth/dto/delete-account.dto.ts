import { Equals, IsNotEmpty, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class DeleteAccountDto {
  @ApiProperty({
    example: 'MiContraseñaActual123!',
    description:
      'Contraseña actual del usuario para confirmar identidad (CA-A4.2)',
  })
  @IsString()
  @IsNotEmpty({
    message: 'La contraseña actual es requerida para eliminar la cuenta',
  })
  password: string;

  @ApiProperty({
    example: 'ELIMINAR',
    description:
      'Palabra de confirmación obligatoria: debe ser exactamente ELIMINAR (CA-A4.2)',
  })
  @IsString()
  @IsNotEmpty()
  @Equals('ELIMINAR', {
    message: 'La confirmación debe ser exactamente la palabra "ELIMINAR"',
  })
  confirmation: string;
}
