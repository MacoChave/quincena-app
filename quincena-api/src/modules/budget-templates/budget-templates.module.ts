import { Module } from '@nestjs/common';
import { BudgetTemplatesService } from './budget-templates.service';
import { BudgetTemplatesController } from './budget-templates.controller';
import { SupabaseModule } from '../../supabase/supabase.module';
import { BudgetAllocationsModule } from '../budget-allocations/budget-allocations.module';

@Module({
  imports: [SupabaseModule, BudgetAllocationsModule],
  providers: [BudgetTemplatesService],
  controllers: [BudgetTemplatesController],
  exports: [BudgetTemplatesService],
})
export class BudgetTemplatesModule {}
