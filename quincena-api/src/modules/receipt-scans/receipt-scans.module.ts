import { Module } from '@nestjs/common';
import { ReceiptScansController } from './receipt-scans.controller';
import { ReceiptScansService } from './receipt-scans.service';
import { SupabaseModule } from '../../supabase/supabase.module';

@Module({
  imports: [SupabaseModule],
  controllers: [ReceiptScansController],
  providers: [ReceiptScansService],
})
export class ReceiptScansModule {}
