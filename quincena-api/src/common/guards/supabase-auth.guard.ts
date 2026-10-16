import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient } from '@supabase/supabase-js';

@Injectable()
export class SupabaseAuthGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authHeader: string | undefined = request.headers['authorization'];

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException(
        'Se requiere token de autorización (Bearer)',
      );
    }

    const token = authHeader.replace('Bearer ', '');

    const publishableKey =
      this.config.get<string>('SUPABASE_PUBLISHABLE_KEY') ||
      this.config.get<string>('SUPABASE_ANON_KEY');

    // Verificamos el token directamente con Supabase (getUser hace la validación)
    const supabase = createClient(
      this.config.getOrThrow<string>('SUPABASE_URL'),
      publishableKey || '',
      {
        global: { headers: { Authorization: `Bearer ${token}` } },
        auth: { autoRefreshToken: false, persistSession: false },
      },
    );

    const { data, error } = await supabase.auth.getUser();

    if (error || !data.user) {
      throw new UnauthorizedException('Token inválido o expirado');
    }

    // Inyectamos el usuario y el token en el request para uso posterior
    request.user = data.user;
    request.accessToken = token;

    return true;
  }
}
