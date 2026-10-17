import { IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SaveFromCycleDto {
  @ApiProperty({
    example: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    description:
      'ID del ciclo quincenal desde el cual guardar las asignaciones como plantilla maestra',
  })
  @IsUUID()
  cycle_id: string;
}
