import { Module } from '@nestjs/common';
import { BudgetTemplatesService } from './budget-templates.service';
import { BudgetTemplatesController } from './budget-templates.controller';
import { SupabaseModule } from '../../supabase/supabase.module';

@Module({
  imports: [SupabaseModule],
  providers: [BudgetTemplatesService],
  controllers: [BudgetTemplatesController],
})
export class BudgetTemplatesModule {}
