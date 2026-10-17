import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import {
  CreateBudgetTemplateDto,
  QuincenaPeriod,
} from './create-budget-template.dto';
import { UpdateBudgetTemplateDto } from './update-budget-template.dto';
import { ApplyBudgetTemplateDto } from './apply-budget-template.dto';
import { SaveFromCycleDto } from './save-from-cycle.dto';

describe('BudgetTemplate DTOs', () => {
  describe('CreateBudgetTemplateDto', () => {
    it('should validate with destination_account_id', async () => {
      const dto = plainToInstance(CreateBudgetTemplateDto, {
        period: QuincenaPeriod.FIRST_HALF,
        category_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        destination_account_id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        default_amount: 800,
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should validate with financial_account_id alias', async () => {
      const dto = plainToInstance(CreateBudgetTemplateDto, {
        period: QuincenaPeriod.SECOND_HALF,
        category_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        financial_account_id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        default_amount: 1200,
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should validate without destination account (optional)', async () => {
      const dto = plainToInstance(CreateBudgetTemplateDto, {
        period: QuincenaPeriod.FIRST_HALF,
        category_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        default_amount: 450,
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should fail with invalid period', async () => {
      const dto = plainToInstance(CreateBudgetTemplateDto, {
        period: 'monthly' as any,
        category_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        default_amount: 450,
      });

      const errors = await validate(dto);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0].property).toBe('period');
    });
  });

  describe('UpdateBudgetTemplateDto', () => {
    it('should validate with financial_account_id alias', async () => {
      const dto = plainToInstance(UpdateBudgetTemplateDto, {
        default_amount: 950,
        financial_account_id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });
  });

  describe('ApplyBudgetTemplateDto', () => {
    it('should validate with cycle_id and overwrite false/true', async () => {
      const dto = plainToInstance(ApplyBudgetTemplateDto, {
        cycle_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        overwrite: true,
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should validate with cycle_id only (overwrite is optional)', async () => {
      const dto = plainToInstance(ApplyBudgetTemplateDto, {
        cycle_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should fail if cycle_id is invalid UUID', async () => {
      const dto = plainToInstance(ApplyBudgetTemplateDto, {
        cycle_id: '123',
      });

      const errors = await validate(dto);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0].property).toBe('cycle_id');
    });
  });

  describe('SaveFromCycleDto', () => {
    it('should validate with valid cycle_id', async () => {
      const dto = plainToInstance(SaveFromCycleDto, {
        cycle_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      });

      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('should fail if cycle_id is missing or invalid', async () => {
      const dto = plainToInstance(SaveFromCycleDto, {});

      const errors = await validate(dto);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0].property).toBe('cycle_id');
    });
  });
});
