import { Test, TestingModule } from '@nestjs/testing';
import { BudgetTemplatesController } from './budget-templates.controller';
import { BudgetTemplatesService } from './budget-templates.service';
import { QuincenaPeriod } from './dto/create-budget-template.dto';
import { User } from '@supabase/supabase-js';

import { SupabaseAuthGuard } from '../../common/guards/supabase-auth.guard';

describe('BudgetTemplatesController', () => {
  let controller: BudgetTemplatesController;
  let mockService: any;

  const mockUser = {
    id: 'user-uuid-1',
    email: 'user@example.com',
  } as User;

  beforeEach(async () => {
    mockService = {
      findByPeriod: jest.fn(),
      create: jest.fn(),
      apply: jest.fn(),
      saveFromCycle: jest.fn(),
      update: jest.fn(),
      remove: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [BudgetTemplatesController],
      providers: [
        {
          provide: BudgetTemplatesService,
          useValue: mockService,
        },
      ],
    })
      .overrideGuard(SupabaseAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<BudgetTemplatesController>(
      BudgetTemplatesController,
    );
  });

  it('should call service.findByPeriod with period and token', async () => {
    mockService.findByPeriod.mockResolvedValue([{ id: 'tmpl-1' }]);

    const result = await controller.findByPeriod(
      mockUser,
      QuincenaPeriod.FIRST_HALF,
      'mock-token',
    );

    expect(mockService.findByPeriod).toHaveBeenCalledWith(
      'user-uuid-1',
      QuincenaPeriod.FIRST_HALF,
      'mock-token',
    );
    expect(result).toEqual([{ id: 'tmpl-1' }]);
  });

  it('should call service.apply with dto and token', async () => {
    const applyDto = { cycle_id: 'cycle-uuid-1', overwrite: true };
    mockService.apply.mockResolvedValue({ allocations: [], summary: {} });

    const result = await controller.apply(mockUser, applyDto, 'mock-token');

    expect(mockService.apply).toHaveBeenCalledWith(
      'user-uuid-1',
      applyDto,
      'mock-token',
    );
    expect(result).toHaveProperty('allocations');
  });

  it('should call service.saveFromCycle with dto and token', async () => {
    const saveDto = { cycle_id: 'cycle-uuid-1' };
    mockService.saveFromCycle.mockResolvedValue([{ id: 'tmpl-saved' }]);

    const result = await controller.saveFromCycle(
      mockUser,
      saveDto,
      'mock-token',
    );

    expect(mockService.saveFromCycle).toHaveBeenCalledWith(
      'user-uuid-1',
      saveDto,
      'mock-token',
    );
    expect(result).toEqual([{ id: 'tmpl-saved' }]);
  });

  it('should call service.update with id, dto and token', async () => {
    const updateDto = { default_amount: 800 };
    mockService.update.mockResolvedValue({ id: 'tmpl-1', default_amount: 800 });

    const result = await controller.update(
      'tmpl-1',
      mockUser,
      updateDto,
      'mock-token',
    );

    expect(mockService.update).toHaveBeenCalledWith(
      'tmpl-1',
      'user-uuid-1',
      updateDto,
      'mock-token',
    );
    expect(result.default_amount).toBe(800);
  });

  it('should call service.remove with id and token', async () => {
    mockService.remove.mockResolvedValue({ id: 'tmpl-1' });

    const result = await controller.remove('tmpl-1', mockUser, 'mock-token');

    expect(mockService.remove).toHaveBeenCalledWith(
      'tmpl-1',
      'user-uuid-1',
      'mock-token',
    );
    expect(result).toEqual({ id: 'tmpl-1' });
  });
});
