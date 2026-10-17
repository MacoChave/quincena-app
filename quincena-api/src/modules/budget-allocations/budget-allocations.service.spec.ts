import { Test, TestingModule } from '@nestjs/testing';
import {
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { BudgetAllocationsService } from './budget-allocations.service';
import { SupabaseService } from '../../supabase/supabase.service';

describe('BudgetAllocationsService', () => {
  let service: BudgetAllocationsService;
  let mockSupabaseService: any;
  let mockClient: any;

  beforeEach(async () => {
    mockClient = {
      from: jest.fn(),
    };

    mockSupabaseService = {
      getAuthenticatedClient: jest.fn().mockReturnValue(mockClient),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BudgetAllocationsService,
        { provide: SupabaseService, useValue: mockSupabaseService },
      ],
    }).compile();

    service = module.get<BudgetAllocationsService>(BudgetAllocationsService);
  });

  describe('findByCycle', () => {
    it('should calculate "Por Asignar" and return allocations with destination_account', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'cycle-1', total_income: 3000, is_closed: false },
          error: null,
        }),
      };

      const allocQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        order: jest.fn().mockResolvedValue({
          data: [
            {
              id: 'alloc-1',
              cycle_id: 'cycle-1',
              category_id: 'cat-1',
              destination_account_id: 'acc-1',
              allocated_amount: 1000,
              categories: {
                id: 'cat-1',
                name: 'Alquiler',
                icon: 'home',
                color_hex: '#FF0000',
              },
              destination_account: {
                id: 'acc-1',
                name: 'Cuenta Banco',
                color_hex: '#00FF00',
                icon: 'account_balance',
              },
            },
          ],
          error: null,
        }),
      };

      const txQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockResolvedValue({
          data: [{ allocation_id: 'alloc-1', amount: 200 }],
          error: null,
        }),
      };

      mockClient.from.mockImplementation((table: string) => {
        if (table === 'biweekly_cycles') return cycleQuery;
        if (table === 'budget_allocations') return allocQuery;
        if (table === 'transactions') return txQuery;
      });

      const result = await service.findByCycle(
        'cycle-1',
        'user-1',
        'mock-token',
      );

      expect(allocQuery.select).toHaveBeenCalledWith(
        '*, categories(id, name, icon, color_hex), destination_account:financial_accounts(id, name, color_hex, icon)',
      );
      expect(result.allocations[0].spent_amount).toBe(200);
      expect(result.allocations[0].available_amount).toBe(800);
      expect((result.summary as any).unallocated).toBe(2000); // 3000 - 1000
      expect((result.summary as any).is_balanced).toBe(false);
    });

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
        service.findByCycle('cycle-1', 'user-1', 'token'),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('create', () => {
    it('should map financial_account_id to destination_account_id and insert', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'cycle-1', is_closed: false },
          error: null,
        }),
      };

      const allocQuery = {
        insert: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: {
            id: 'alloc-1',
            destination_account_id: 'acc-1',
            allocated_amount: 500,
          },
          error: null,
        }),
      };

      mockClient.from.mockImplementation((table: string) => {
        if (table === 'biweekly_cycles') return cycleQuery;
        if (table === 'budget_allocations') return allocQuery;
      });

      const result = await service.create(
        'user-1',
        {
          cycle_id: 'cycle-1',
          category_id: 'cat-1',
          financial_account_id: 'acc-1',
          allocated_amount: 500,
        },
        'token',
      );

      expect(allocQuery.insert).toHaveBeenCalledWith({
        cycle_id: 'cycle-1',
        category_id: 'cat-1',
        destination_account_id: 'acc-1',
        allocated_amount: 500,
      });
      expect(result.id).toBe('alloc-1');
    });

    it('should throw BadRequestException if cycle is closed (RN-01)', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'cycle-1', is_closed: true },
          error: null,
        }),
      };
      mockClient.from.mockReturnValue(cycleQuery);

      await expect(
        service.create(
          'user-1',
          {
            cycle_id: 'cycle-1',
            category_id: 'cat-1',
            allocated_amount: 500,
          },
          'token',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw ConflictException on duplicate category (code 23505)', async () => {
      const cycleQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'cycle-1', is_closed: false },
          error: null,
        }),
      };

      const allocQuery = {
        insert: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: null,
          error: { code: '23505', message: 'duplicate key' },
        }),
      };

      mockClient.from.mockImplementation((table: string) => {
        if (table === 'biweekly_cycles') return cycleQuery;
        if (table === 'budget_allocations') return allocQuery;
      });

      await expect(
        service.create(
          'user-1',
          {
            cycle_id: 'cycle-1',
            category_id: 'cat-1',
            allocated_amount: 500,
          },
          'token',
        ),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('update', () => {
    it('should resolve financial_account_id alias on update', async () => {
      const existingQuery = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: {
            id: 'alloc-1',
            cycle_id: 'cycle-1',
            biweekly_cycles: { user_id: 'user-1', is_closed: false },
          },
          error: null,
        }),
      };

      const updateQuery = {
        update: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'alloc-1', destination_account_id: 'new-acc-1' },
          error: null,
        }),
      };

      mockClient.from.mockImplementation((table: string) => {
        if (table === 'budget_allocations') {
          // first call for existing, second for update
          if (!existingQuery.select.mock.calls.length) {
            return existingQuery;
          }
          return updateQuery;
        }
      });

      const result = await service.update(
        'alloc-1',
        'user-1',
        { financial_account_id: 'new-acc-1' },
        'token',
      );

      expect(updateQuery.update).toHaveBeenCalledWith(
        expect.objectContaining({ destination_account_id: 'new-acc-1' }),
      );
      expect(result.destination_account_id).toBe('new-acc-1');
    });
  });
});
