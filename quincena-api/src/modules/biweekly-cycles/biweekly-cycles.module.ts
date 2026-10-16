import { Module } from '@nestjs/common';
import { BiweeklyCyclesController } from './biweekly-cycles.controller';
import { BiweeklyCyclesService } from './biweekly-cycles.service';
import { SupabaseModule } from '../../supabase/supabase.module';

@Module({
  imports: [SupabaseModule],
  controllers: [BiweeklyCyclesController],
  providers: [BiweeklyCyclesService],
  exports: [BiweeklyCyclesService],
})
export class BiweeklyCyclesModule {}
