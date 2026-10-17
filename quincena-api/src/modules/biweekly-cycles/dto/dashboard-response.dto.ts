import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { QuincenaPeriod } from './create-biweekly-cycle.dto';

export class DashboardCycleDto {
  @ApiProperty({
    example: '123e4567-e89b-12d3-a456-426614174000',
    description: 'ID del ciclo',
  })
  id: string;

  @ApiProperty({ example: 2026, description: 'Año del ciclo' })
  year: number;

  @ApiProperty({ example: 10, description: 'Mes del ciclo (1-12)' })
  month: number;

  @ApiProperty({
    enum: QuincenaPeriod,
    example: QuincenaPeriod.FIRST_HALF,
    description: 'Período quincenal',
  })
  period: QuincenaPeriod;

  @ApiProperty({
    example: '2026-10-01',
    description: 'Fecha de inicio (YYYY-MM-DD)',
  })
  start_date: string;

  @ApiProperty({
    example: '2026-10-15',
    description: 'Fecha de fin (YYYY-MM-DD)',
  })
  end_date: string;

  @ApiProperty({ example: 7000.0, description: 'Ingreso total del ciclo' })
  total_income: number;

  @ApiProperty({
    example: false,
    description: 'Indica si el ciclo está cerrado',
  })
  is_closed: boolean;

  @ApiPropertyOptional({
    example: '123e4567-e89b-12d3-a456-426614174001',
    description: 'Cuenta bancaria/destino del ingreso',
  })
  income_destination_account_id?: string;

  @ApiPropertyOptional({
    example: 0,
    description: 'Monto arrastrado de ciclo anterior',
  })
  rolled_over_amount?: number;

  @ApiPropertyOptional({ example: '2026-10-01T00:00:00.000Z' })
  created_at?: string;

  @ApiPropertyOptional({ example: '2026-10-01T00:00:00.000Z' })
  updated_at?: string;
}

export class DashboardSummaryDto {
  @ApiProperty({
    example: 7000.0,
    description: 'Ingreso total presupuestado para la quincena',
  })
  total_income: number;

  @ApiProperty({
    example: 6500.0,
    description: 'Suma de montos asignados a todas las categorías',
  })
  total_allocated: number;

  @ApiProperty({
    example: 1200.0,
    description: 'Gasto real acumulado en la quincena',
  })
  total_spent: number;

  @ApiProperty({
    example: 5300.0,
    description: 'Disponible restante del presupuesto asignado',
  })
  total_available: number;

  @ApiProperty({
    example: 500.0,
    description:
      'Ingreso pendiente de asignar (total_income - total_allocated)',
  })
  unallocated: number;

  @ApiProperty({
    example: false,
    description:
      'Indica si total_income == total_allocated (presupuesto base cero)',
  })
  is_balanced: boolean;
}

export class DashboardCategoryDto {
  @ApiProperty({
    example: '123e4567-e89b-12d3-a456-426614174010',
    description: 'ID de la asignación',
  })
  id: string;

  @ApiProperty({
    example: '123e4567-e89b-12d3-a456-426614174020',
    description: 'ID de la categoría',
  })
  category_id: string;

  @ApiProperty({
    example: 'Supermercado',
    description: 'Nombre de la categoría',
  })
  name: string;

  @ApiProperty({
    example: 'shopping_cart',
    description: 'Ícono de la categoría',
  })
  icon: string;

  @ApiProperty({
    example: '#4CAF50',
    description: 'Color hexadecimal de la categoría',
  })
  color_hex: string;

  @ApiProperty({
    example: 2000.0,
    description: 'Monto presupuestado para esta categoría',
  })
  allocated_amount: number;

  @ApiProperty({ example: 500.0, description: 'Monto ejecutado/gastado' })
  spent_amount: number;

  @ApiProperty({ example: 1500.0, description: 'Monto restante disponible' })
  available_amount: number;

  @ApiProperty({ example: 25.0, description: 'Porcentaje ejecutado (0-100+)' })
  spent_percentage: number;
}

export class SuggestedPeriodDto {
  @ApiProperty({ example: 2026, description: 'Año sugerido' })
  year: number;

  @ApiProperty({ example: 10, description: 'Mes sugerido (1-12)' })
  month: number;

  @ApiProperty({
    enum: QuincenaPeriod,
    example: QuincenaPeriod.FIRST_HALF,
    description: 'Período sugerido',
  })
  period: QuincenaPeriod;

  @ApiProperty({
    example: '2026-10-01',
    description: 'Fecha de inicio del período sugerido',
  })
  start_date: string;

  @ApiProperty({
    example: '2026-10-15',
    description: 'Fecha de fin del período sugerido',
  })
  end_date: string;
}

export class DashboardResponseDto {
  @ApiProperty({
    example: true,
    description: 'Indica si el usuario tiene un ciclo quincenal activo',
  })
  has_active_cycle: boolean;

  @ApiPropertyOptional({
    type: DashboardCycleDto,
    nullable: true,
    description: 'Ciclo quincenal activo actual',
  })
  cycle: DashboardCycleDto | null;

  @ApiProperty({
    type: DashboardSummaryDto,
    description: 'Resumen consolidado financiero del ciclo',
  })
  summary: DashboardSummaryDto;

  @ApiProperty({
    type: [DashboardCategoryDto],
    description: 'Categorías presupuestadas con gastos y disponibilidad',
  })
  categories: DashboardCategoryDto[];

  @ApiPropertyOptional({
    type: SuggestedPeriodDto,
    nullable: true,
    description:
      'Período sugerido para abrir una nueva quincena (presente cuando has_active_cycle es false)',
  })
  suggested_period: SuggestedPeriodDto | null;
}
