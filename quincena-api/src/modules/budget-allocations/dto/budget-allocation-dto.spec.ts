import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { CreateBudgetAllocationDto } from './create-budget-allocation.dto';
import { UpdateBudgetAllocationDto } from './update-budget-allocation.dto';

describe('BudgetAllocation DTOs', () => {
  describe('CreateBudgetAllocationDto', () => {
    it('should validate with destination_account_id', async () => {
      const dto = plainToInstance(CreateBudgetAllocationDto, {
        cycle_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        category_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        destination_account_id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        allocated_amount: 500,
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should validate with financial_account_id alias', async () => {
      const dto = plainToInstance(CreateBudgetAllocationDto, {
        cycle_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        category_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        financial_account_id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        allocated_amount: 750.5,
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should validate without any account id (optional)', async () => {
      const dto = plainToInstance(CreateBudgetAllocationDto, {
        cycle_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        category_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        allocated_amount: 300,
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should fail if allocated_amount is negative', async () => {
      const dto = plainToInstance(CreateBudgetAllocationDto, {
        cycle_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        category_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        allocated_amount: -50,
      });

      const errors = await validate(dto);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0].property).toBe('allocated_amount');
    });

    it('should fail if cycle_id is not a valid UUID', async () => {
      const dto = plainToInstance(CreateBudgetAllocationDto, {
        cycle_id: 'not-a-uuid',
        category_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        allocated_amount: 100,
      });

      const errors = await validate(dto);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0].property).toBe('cycle_id');
    });
  });

  describe('UpdateBudgetAllocationDto', () => {
    it('should validate update with financial_account_id alias', async () => {
      const dto = plainToInstance(UpdateBudgetAllocationDto, {
        allocated_amount: 600,
        financial_account_id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should validate update with destination_account_id', async () => {
      const dto = plainToInstance(UpdateBudgetAllocationDto, {
        destination_account_id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });
  });
});
