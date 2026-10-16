import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { SupabaseModule } from './supabase/supabase.module';
import { ProfilesModule } from './modules/profiles/profiles.module';
import { FinancialAccountsModule } from './modules/financial-accounts/financial-accounts.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { BudgetTemplatesModule } from './modules/budget-templates/budget-templates.module';
import { BiweeklyCyclesModule } from './modules/biweekly-cycles/biweekly-cycles.module';
import { BudgetAllocationsModule } from './modules/budget-allocations/budget-allocations.module';
import { TransactionsModule } from './modules/transactions/transactions.module';
import { ReceiptScansModule } from './modules/receipt-scans/receipt-scans.module';

@Module({
  imports: [
    // Configuración de variables de entorno (carga .env)
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),

    // Módulo Supabase compartido
    SupabaseModule,

    // Módulos del dominio
    ProfilesModule,
    FinancialAccountsModule,
    CategoriesModule,
    BudgetTemplatesModule,
    BiweeklyCyclesModule,
    BudgetAllocationsModule,
    TransactionsModule,
    ReceiptScansModule,
  ],
})
export class AppModule {}
