import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { User } from '@supabase/supabase-js';

/**
 * Decorador que extrae el usuario autenticado del request.
 * Requiere que SupabaseAuthGuard haya sido aplicado previamente.
 *
 * @example
 * async getProfile(@CurrentUser() user: User) { ... }
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): User => {
    const request = ctx.switchToHttp().getRequest();
    return request.user as User;
  },
);

/**
 * Decorador que extrae el access token JWT del request.
 * Útil para construir clientes Supabase autenticados en los servicios.
 *
 * @example
 * async getProfile(@AccessToken() token: string) { ... }
 */
export const AccessToken = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string => {
    const request = ctx.switchToHttp().getRequest();
    return request.accessToken as string;
  },
);
