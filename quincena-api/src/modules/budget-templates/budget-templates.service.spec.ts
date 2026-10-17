import { Test, TestingModule } from '@nestjs/testing';
import {
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { BudgetTemplatesService } from './budget-templates.service';
import { SupabaseService } from '../../supabase/supabase.service';
import { BudgetAllocationsService } from '../budget-allocations/budget-allocations.service';
import { QuincenaPeriod } from './dto/create-budget-template.dto';

describe('BudgetTemplatesService', () => {
  let service: BudgetTemplatesService;
  let mockSupabaseService: any;
  let mockBudgetAllocationsService: any;
  let mockClient: any;

  beforeEach(async () => {
    mockClient = {
      from: jest.fn(),
    };

    mockSupabaseService = {
      getAuthenticatedClient: jest.fn().mockReturnValue(mockClient),
    };

    mockBudgetAllocationsService = {
      findByCycle: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BudgetTemplatesService,
        { provide: SupabaseService, useValue: mockSupabaseService },
        {
          provide: BudgetAllocationsService,
          useValue: mockBudgetAllocationsService,
        },
      ],
    }).compile();

    service = module.get<BudgetTemplatesService>(BudgetTemplatesService);
  });

  describe('findByPeriod', () => {
    it('should query templates with categories and destination_account joins', async () => {
      const mockTemplates = [
        {
          id: 'tmpl-1',
          user_id: 'user-1',
          period: QuincenaPeriod.FIRST_HALF,
          category_id: 'cat-1',
          destination_account_id: 'acc-1',
          default_amount: 500,
          categories: {
            id: 'cat-1',
            name: 'Comida',
            icon: 'food',
            color_hex: '#FF0000',
          },
          destination_account: {
            id: 'acc-1',
            name: 'Nómina',
            color_hex: '#00FF00',
            icon: 'account_balance',
          },
        },
      ];

      const queryChain = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        order: jest
          .fn()
          .mockResolvedValue({ data: mockTemplates, error: null }),
      };

      mockClient.from.mockReturnValue(queryChain);

      const result = await service.findByPeriod(
        'user-1',
        QuincenaPeriod.FIRST_HALF,
        'mock-token',
      );

      expect(mockClient.from).toHaveBeenCalledWith('budget_templates');
      expect(queryChain.select).toHaveBeenCalledWith(
        '*, categories(id, name, icon, color_hex), destination_account:financial_accounts(id, name, color_hex, icon)',
      );
      expect(result).toEqual(mockTemplates);
    });
  });

  describe('create', () => {
    it('should resolve financial_account_id alias to destination_account_id', async () => {
      const queryChain = {
        insert: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'tmpl-1', destination_account_id: 'acc-1' },
          error: null,
        }),
      };
      mockClient.from.mockReturnValue(queryChain);

      const result = await service.create(
        'user-1',
        {
          period: QuincenaPeriod.FIRST_HALF,
          category_id: 'cat-1',
          financial_account_id: 'acc-1',
          default_amount: 500,
        },
        'mock-token',
      );

      expect(queryChain.insert).toHaveBeenCalledWith({
        user_id: 'user-1',
        period: QuincenaPeriod.FIRST_HALF,
        category_id: 'cat-1',
        destination_account_id: 'acc-1',
        default_amount: 500,
      });
      expect(result.id).toBe('tmpl-1');
    });

    it('should throw ConflictException on duplicate category in period (code 23505)', async () => {
      const queryChain = {
        insert: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: null,
          error: { code: '23505', message: 'duplicate key' },
        }),
      };
      mockClient.from.mockReturnValue(queryChain);

      await expect(
        service.create(
          'user-1',
          {
            period: QuincenaPeriod.FIRST_HALF,
            category_id: 'cat-1',
            default_amount: 500,
          },
          'mock-token',
        ),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('apply', () => {
    it('should throw NotFoundException if cycle does not exist', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest
          .fn()
          .mockResolvedValue({ data: null, error: { message: 'Not found' } }),
      };
      mockClient.from.mockReturnValue(cycleQuery);

      await expect(
        service.apply('user-1', { cycle_id: 'cycle-1' }, 'token'),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException if cycle is closed (RN-01)', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: {
            id: 'cycle-1',
            period: 'first_half',
            is_closed: true,
            user_id: 'user-1',
          },
          error: null,
        }),
      };
      mockClient.from.mockReturnValue(cycleQuery);

      await expect(
        service.apply('user-1', { cycle_id: 'cycle-1' }, 'token'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw ConflictException if cycle has existing allocations and overwrite is false', async () => {
      // 1. Cycle lookup
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: {
            id: 'cycle-1',
            period: 'first_half',
            is_closed: false,
            user_id: 'user-1',
          },
          error: null,
        }),
      };
      // 2. Existing allocations check
      const allocQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockResolvedValue({
          data: [{ id: 'alloc-1' }],
          error: null,
        }),
      };

      mockClient.from.mockImplementation((table: string) => {
        if (table === 'biweekly_cycles') return cycleQuery;
        if (table === 'budget_allocations') return allocQuery;
      });

      await expect(
        service.apply(
          'user-1',
          { cycle_id: 'cycle-1', overwrite: false },
          'token',
        ),
      ).rejects.toThrow(ConflictException);
    });

    it('should delete existing allocations and insert template rows when overwrite is true', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: {
            id: 'cycle-1',
            period: 'first_half',
            is_closed: false,
            user_id: 'user-1',
          },
          error: null,
        }),
      };

      const existingAllocQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockResolvedValue({
          data: [{ id: 'alloc-1' }],
          error: null,
        }),
        delete: jest.fn().mockReturnThis(),
        insert: jest.fn().mockResolvedValue({ data: null, error: null }),
      };

      const templatesQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
      };
      // chain eq(user_id).eq(period)
      templatesQuery.eq.mockImplementation((col: string) => {
        if (col === 'period') {
          return Promise.resolve({
            data: [
              {
                category_id: 'cat-1',
                destination_account_id: 'acc-1',
                default_amount: 800,
              },
            ],
            error: null,
          });
        }
        return templatesQuery;
      });

      mockClient.from.mockImplementation((table: string) => {
        if (table === 'biweekly_cycles') return cycleQuery;
        if (table === 'budget_allocations') return existingAllocQuery;
        if (table === 'budget_templates') return templatesQuery;
      });

      mockBudgetAllocationsService.findByCycle.mockResolvedValue({
        allocations: [{ id: 'new-alloc-1', allocated_amount: 800 }],
        summary: { total_income: 1000, unallocated: 200 },
      });

      const result = await service.apply(
        'user-1',
        { cycle_id: 'cycle-1', overwrite: true },
        'token',
      );

      expect(existingAllocQuery.delete).toHaveBeenCalled();
      expect(existingAllocQuery.insert).toHaveBeenCalledWith([
        {
          cycle_id: 'cycle-1',
          category_id: 'cat-1',
          destination_account_id: 'acc-1',
          allocated_amount: 800,
        },
      ]);
      expect(mockBudgetAllocationsService.findByCycle).toHaveBeenCalledWith(
        'cycle-1',
        'user-1',
        'token',
      );
      expect(result.summary.unallocated).toBe(200);
    });
  });

  describe('saveFromCycle', () => {
    it('should throw NotFoundException if cycle does not exist', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest
          .fn()
          .mockResolvedValue({ data: null, error: { message: 'Not found' } }),
      };
      mockClient.from.mockReturnValue(cycleQuery);

      await expect(
        service.saveFromCycle('user-1', { cycle_id: 'cycle-1' }, 'token'),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException if cycle has no allocations', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'cycle-1', period: 'second_half', user_id: 'user-1' },
          error: null,
        }),
      };

      const allocQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockResolvedValue({ data: [], error: null }),
      };

      mockClient.from.mockImplementation((table: string) => {
        if (table === 'biweekly_cycles') return cycleQuery;
        if (table === 'budget_allocations') return allocQuery;
      });

      await expect(
        service.saveFromCycle('user-1', { cycle_id: 'cycle-1' }, 'token'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should upsert allocations to budget_templates with cycle period', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'cycle-1', period: 'second_half', user_id: 'user-1' },
          error: null,
        }),
      };

      const allocQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockResolvedValue({
          data: [
            {
              category_id: 'cat-1',
              destination_account_id: 'acc-1',
              allocated_amount: 650,
            },
            {
              category_id: 'cat-2',
              destination_account_id: null,
              allocated_amount: 300,
            },
          ],
          error: null,
        }),
      };

      const templatesQuery = {
        upsert: jest.fn().mockReturnThis(),
        select: jest.fn().mockResolvedValue({
          data: [
            {
              id: 't1',
              period: 'second_half',
              category_id: 'cat-1',
              default_amount: 650,
            },
            {
              id: 't2',
              period: 'second_half',
              category_id: 'cat-2',
              default_amount: 300,
            },
          ],
          error: null,
        }),
      };

      mockClient.from.mockImplementation((table: string) => {
        if (table === 'biweekly_cycles') return cycleQuery;
        if (table === 'budget_allocations') return allocQuery;
        if (table === 'budget_templates') return templatesQuery;
      });

      const result = await service.saveFromCycle(
        'user-1',
        { cycle_id: 'cycle-1' },
        'token',
      );

      expect(templatesQuery.upsert).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({
            user_id: 'user-1',
            period: 'second_half',
            category_id: 'cat-1',
            destination_account_id: 'acc-1',
            default_amount: 650,
          }),
          expect.objectContaining({
            user_id: 'user-1',
            period: 'second_half',
            category_id: 'cat-2',
            destination_account_id: null,
            default_amount: 300,
          }),
        ]),
        { onConflict: 'user_id,period,category_id' },
      );
      expect(result.length).toBe(2);
    });
  });
});
