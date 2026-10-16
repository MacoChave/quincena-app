import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

@Injectable()
export class SupabaseService implements OnModuleInit {
  private _client: SupabaseClient;
  private _adminClient: SupabaseClient;

  constructor(private readonly config: ConfigService) {}

  private get publishableKey(): string {
    const key =
      this.config.get<string>('SUPABASE_PUBLISHABLE_KEY') ||
      this.config.get<string>('SUPABASE_ANON_KEY');
    if (!key) {
      throw new Error(
        'Falta configurar SUPABASE_PUBLISHABLE_KEY (o SUPABASE_ANON_KEY) en las variables de entorno.',
      );
    }
    return key;
  }

  private get secretKey(): string {
    const key =
      this.config.get<string>('SUPABASE_SECRET_KEY') ||
      this.config.get<string>('SUPABASE_SERVICE_ROLE_KEY');
    if (!key) {
      throw new Error(
        'Falta configurar SUPABASE_SECRET_KEY (o SUPABASE_SERVICE_ROLE_KEY) en las variables de entorno.',
      );
    }
    return key;
  }

  onModuleInit() {
    const url = this.config.getOrThrow<string>('SUPABASE_URL');

    // Cliente público (respeta RLS de Supabase)
    this._client = createClient(url, this.publishableKey);

    // Cliente admin (service role / secret key, bypass RLS — uso interno únicamente)
    this._adminClient = createClient(url, this.secretKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
  }

  /**
   * Devuelve un cliente Supabase autenticado con el JWT del usuario.
   * Utiliza el cliente base con el token inyectado en el header.
   */
  getAuthenticatedClient(accessToken: string): SupabaseClient {
    return createClient(
      this.config.getOrThrow<string>('SUPABASE_URL'),
      this.publishableKey,
      {
        global: {
          headers: { Authorization: `Bearer ${accessToken}` },
        },
        auth: { autoRefreshToken: false, persistSession: false },
      },
    );
  }

  /** Cliente anónimo (solo lectura pública, sin RLS bypass) */
  get client(): SupabaseClient {
    return this._client;
  }

  /** Cliente con service role (admin, bypass RLS — solo para tareas de sistema) */
  get adminClient(): SupabaseClient {
    return this._adminClient;
  }
}
