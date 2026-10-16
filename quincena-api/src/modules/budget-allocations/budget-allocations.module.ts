import { Module } from '@nestjs/common';
import { BudgetAllocationsController } from './budget-allocations.controller';
import { BudgetAllocationsService } from './budget-allocations.service';
import { SupabaseModule } from '../../supabase/supabase.module';

@Module({
  imports: [SupabaseModule],
  controllers: [BudgetAllocationsController],
  providers: [BudgetAllocationsService],
  exports: [BudgetAllocationsService],
})
export class BudgetAllocationsModule {}
