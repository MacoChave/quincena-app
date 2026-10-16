import { PartialType } from '@nestjs/swagger';
import { CreateFinancialAccountDto } from './create-financial-account.dto';
import { IsOptional, IsBoolean } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateFinancialAccountDto extends PartialType(CreateFinancialAccountDto) {
  @ApiPropertyOptional({ example: true, description: 'Archivar la cuenta' })
  @IsOptional()
  @IsBoolean()
  is_archived?: boolean;
}
