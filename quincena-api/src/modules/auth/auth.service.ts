import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RequestPasswordResetDto } from './dto/request-password-reset.dto';
import { UpdatePasswordDto } from './dto/update-password.dto';
import { DeleteAccountDto } from './dto/delete-account.dto';
import { User } from '@supabase/supabase-js';

const RECEIPT_SCANS_BUCKET = 'receipts';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(private readonly supabase: SupabaseService) {}

  /**
   * RF-AUTH-01: Registro de nuevo usuario con email y contraseña.
   * Crea el usuario en Supabase Auth y dispara el trigger handle_new_user en BD.
   */
  async register(dto: RegisterDto) {
    const { data, error } = await this.supabase.client.auth.signUp({
      email: dto.email,
      password: dto.password,
      options: {
        data: {
          full_name: dto.full_name || '',
        },
      },
    });

    if (error) {
      throw new BadRequestException(error.message);
    }

    return {
      message:
        'Registro exitoso. Se ha enviado un correo de confirmación si está habilitado.',
      user: data.user,
      session: data.session,
    };
  }

  /**
   * RF-AUTH-01: Inicio de sesión con correo y contraseña.
   * Retorna access_token y refresh_token.
   */
  async login(dto: LoginDto) {
    const { data, error } = await this.supabase.client.auth.signInWithPassword({
      email: dto.email,
      password: dto.password,
    });

    if (error) {
      throw new UnauthorizedException(
        'Credenciales inválidas o cuenta no confirmada',
      );
    }

    return {
      message: 'Inicio de sesión exitoso',
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      token_type: data.session.token_type,
      expires_in: data.session.expires_in,
      user: data.user,
    };
  }

  /**
   * RF-AUTH-02: Solicitud de recuperación de contraseña.
   * CA-A2.2: Mitigación de enumeración de usuarios (siempre responde con mensaje genérico).
   * Redirige al deep link quincena://auth/reset-password (CA-A2.3).
   */
  async requestPasswordReset(dto: RequestPasswordResetDto) {
    try {
      await this.supabase.client.auth.resetPasswordForEmail(dto.email, {
        redirectTo: 'quincena://auth/reset-password',
      });
    } catch (err) {
      this.logger.warn(
        `Error al solicitar restablecimiento para ${dto.email}: ${err}`,
      );
    }

    // Respuesta genérica estricta por CA-A2.2
    return {
      message:
        'Si el correo coincide con una cuenta activa, te hemos enviado un enlace o código de restablecimiento.',
    };
  }

  /**
   * RF-AUTH-02: Actualización de contraseña (tras reset o desde ajustes).
   * Si se envía current_password, valida la contraseña actual re-autenticando contra Supabase.
   * Soporta tanto dto.password como dto.new_password.
   */
  async updatePassword(
    user: User,
    dto: UpdatePasswordDto,
    accessToken: string,
  ) {
    const newPassword = dto.new_password || dto.password;
    if (!newPassword) {
      throw new BadRequestException(
        'Se requiere la nueva contraseña (password o new_password)',
      );
    }

    // Si se envía current_password, validar credenciales actuales
    if (dto.current_password) {
      if (!user?.email) {
        throw new BadRequestException(
          'No se pudo identificar el email del usuario para re-autenticación',
        );
      }
      const { error: verifyError } =
        await this.supabase.client.auth.signInWithPassword({
          email: user.email,
          password: dto.current_password,
        });

      if (verifyError) {
        throw new UnauthorizedException('La contraseña actual es incorrecta');
      }
    }

    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { data, error } = await client.auth.updateUser({
      password: newPassword,
    });

    if (error) {
      throw new BadRequestException(error.message);
    }

    return {
      message: 'Contraseña actualizada exitosamente.',
      user: data.user,
    };
  }

  /**
   * RF-AUTH-03: Cierre de sesión seguro.
   * Invalida la sesión actual en Supabase Auth.
   */
  async logout(accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { error } = await client.auth.signOut();

    if (error) {
      this.logger.warn(`Aviso en signOut: ${error.message}`);
    }

    return {
      message: 'Sesión cerrada exitosamente.',
    };
  }

  /**
   * RF-AUTH-04: Baja y Eliminación permanente de Cuenta (Delete Account).
   * CA-A4.2: Doble factor (contraseña actual + palabra "ELIMINAR").
   * CA-A4.3: Cascada en base de datos al eliminar el usuario de auth.users.
   * CA-A4.4: Purgado de archivos binarios/imágenes en Supabase Storage (receipts/{user_id}/*).
   * RN-AUTH-02: Irreversibilidad de la baja.
   */
  async deleteAccount(
    userId: string,
    userEmail: string,
    dto: DeleteAccountDto,
  ) {
    // 1. Validar la contraseña actual contra Supabase Auth re-autenticando
    const { error: verifyError } =
      await this.supabase.client.auth.signInWithPassword({
        email: userEmail,
        password: dto.password,
      });

    if (verifyError) {
      throw new UnauthorizedException(
        'Contraseña actual incorrecta. No se puede proceder con la eliminación.',
      );
    }

    // 2. CA-A4.4: Purgar archivos en Supabase Storage (carpeta del usuario)
    try {
      const adminClient = this.supabase.adminClient;
      const { data: files, error: listError } = await adminClient.storage
        .from(RECEIPT_SCANS_BUCKET)
        .list(userId);

      if (!listError && files && files.length > 0) {
        const filePaths = files.map((f) => `${userId}/${f.name}`);
        await adminClient.storage.from(RECEIPT_SCANS_BUCKET).remove(filePaths);
        this.logger.log(
          `Archivos de comprobantes eliminados para usuario ${userId}: ${filePaths.length}`,
        );
      }
    } catch (storageErr) {
      this.logger.error(
        `Error purgado archivos de storage para usuario ${userId}: ${storageErr}`,
      );
    }

    // 3. CA-A4.3: Eliminar el usuario en auth.users usando el cliente admin
    // La FK ON DELETE CASCADE limpiará profiles, accounts, cycles, transactions, etc.
    const { error: deleteUserError } =
      await this.supabase.adminClient.auth.admin.deleteUser(userId);

    if (deleteUserError) {
      this.logger.error(
        `Error al eliminar usuario ${userId}: ${deleteUserError.message}`,
      );
      throw new InternalServerErrorException(
        'Error al eliminar la cuenta del sistema.',
      );
    }

    return {
      message:
        'Tu cuenta y todos tus datos financieros han sido eliminados de forma definitiva e irreversible.',
    };
  }
}
