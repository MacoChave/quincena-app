import { IsEmail, IsNotEmpty, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class LoginDto {
  @ApiProperty({
    example: 'usuario@correo.com',
    description: 'Correo electrónico',
  })
  @IsEmail(
    {},
    { message: 'El correo electrónico debe tener un formato válido' },
  )
  @IsNotEmpty()
  email: string;

  @ApiProperty({ example: 'Quincena2026!', description: 'Contraseña' })
  @IsString()
  @IsNotEmpty()
  password: string;
}
