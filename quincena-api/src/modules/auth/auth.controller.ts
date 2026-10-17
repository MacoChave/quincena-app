import {
  Controller,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiOkResponse,
  ApiCreatedResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RequestPasswordResetDto } from './dto/request-password-reset.dto';
import { UpdatePasswordDto } from './dto/update-password.dto';
import { DeleteAccountDto } from './dto/delete-account.dto';
import { SupabaseAuthGuard } from '../../common/guards/supabase-auth.guard';
import {
  CurrentUser,
  AccessToken,
} from '../../common/decorators/current-user.decorator';
import { User } from '@supabase/supabase-js';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @ApiOperation({
    summary: 'Registro de nuevo usuario (RF-AUTH-01)',
    description:
      'Crea una cuenta con email y contraseña cumpliendo la política de seguridad: ' +
      'mínimo 8 caracteres, al menos 1 mayúscula, 1 minúscula y 1 número (CA-A1.2).',
  })
  @ApiCreatedResponse({ description: 'Usuario registrado exitosamente' })
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Inicio de sesión con correo y contraseña (RF-AUTH-01)',
    description:
      'Autentica las credenciales y devuelve access_token y refresh_token JWT (CA-A1.4).',
  })
  @ApiOkResponse({ description: 'Sesión iniciada con éxito' })
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Solicitud de recuperación de contraseña (RF-AUTH-02)',
    description:
      'Envía un enlace/token al correo para restablecer contraseña. ' +
      'Por mitigación de enumeración de usuarios, la respuesta siempre es genérica (CA-A2.2).',
  })
  @ApiOkResponse({ description: 'Respuesta genérica de confirmación enviada' })
  requestPasswordReset(@Body() dto: RequestPasswordResetDto) {
    return this.authService.requestPasswordReset(dto);
  }

  @Post('update-password')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth('Supabase JWT')
  @UseGuards(SupabaseAuthGuard)
  @ApiOperation({
    summary: 'Actualizar contraseña (RF-AUTH-02, CA-A2.3)',
    description:
      'Establece la nueva contraseña para el usuario autenticado tras seguir el enlace de recuperación o desde ajustes. ' +
      'Si se envía current_password, se valida re-autenticando al usuario.',
  })
  @ApiOkResponse({ description: 'Contraseña actualizada' })
  updatePassword(
    @CurrentUser() user: User,
    @Body() dto: UpdatePasswordDto,
    @AccessToken() token: string,
  ) {
    return this.authService.updatePassword(user, dto, token);
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth('Supabase JWT')
  @UseGuards(SupabaseAuthGuard)
  @ApiOperation({
    summary: 'Cierre de sesión seguro (RF-AUTH-03)',
    description: 'Invalida la sesión actual en el servidor de Supabase Auth.',
  })
  @ApiOkResponse({ description: 'Sesión cerrada exitosamente' })
  logout(@AccessToken() token: string) {
    return this.authService.logout(token);
  }

  @Post('delete-account')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth('Supabase JWT')
  @UseGuards(SupabaseAuthGuard)
  @ApiOperation({
    summary: 'Baja y eliminación irreversible de cuenta (RF-AUTH-04)',
    description:
      'Flujo con doble factor de confirmación (contraseña actual + palabra ELIMINAR). ' +
      'Elimina en cascada todos los registros en BD y purga los comprobantes en Supabase Storage (CA-A4.1 - CA-A4.4, RN-AUTH-02).',
  })
  @ApiOkResponse({ description: 'Cuenta eliminada de forma definitiva' })
  deleteAccount(@CurrentUser() user: User, @Body() dto: DeleteAccountDto) {
    return this.authService.deleteAccount(user.id, user.email, dto);
  }
}
