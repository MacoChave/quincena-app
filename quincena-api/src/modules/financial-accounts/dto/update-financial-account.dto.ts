import { PartialType } from '@nestjs/swagger';
import { CreateFinancialAccountDto } from './create-financial-account.dto';
import { IsOptional, IsBoolean } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateFinancialAccountDto extends PartialType(
  CreateFinancialAccountDto,
) {
  @ApiPropertyOptional({
    example: false,
    description:
      'Estado de archivado de la cuenta (true = archivada / soft delete, false = activa / desarchivada)',
  })
  @IsOptional()
  @IsBoolean()
  is_archived?: boolean;
}
