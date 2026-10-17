import { Module } from '@nestjs/common';
import { BiweeklyCyclesController } from './biweekly-cycles.controller';
import { BiweeklyCyclesService } from './biweekly-cycles.service';
import { SupabaseModule } from '../../supabase/supabase.module';
import { BudgetAllocationsModule } from '../budget-allocations/budget-allocations.module';

@Module({
  imports: [SupabaseModule, BudgetAllocationsModule],
  controllers: [BiweeklyCyclesController],
  providers: [BiweeklyCyclesService],
  exports: [BiweeklyCyclesService],
})
export class BiweeklyCyclesModule {}
