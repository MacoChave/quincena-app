import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException, ConflictException } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { SupabaseService } from '../../supabase/supabase.service';

describe('CategoriesService (RF-CAT-01)', () => {
  let service: CategoriesService;
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
        CategoriesService,
        { provide: SupabaseService, useValue: mockSupabaseService },
      ],
    }).compile();

    service = module.get<CategoriesService>(CategoriesService);
  });

  describe('findAll', () => {
    it('debe listar categorías activas con default_account por defecto', async () => {
      const mockQuery: any = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        order: jest.fn().mockResolvedValue({
          data: [
            {
              id: 'cat-1',
              name: 'Supermercado',
              icon: 'shopping_cart',
              color_hex: '#ADF7B6',
              is_archived: false,
              default_account: { id: 'acc-1', name: 'Monetaria BAC' },
            },
          ],
          error: null,
        }),
      };

      mockClient.from.mockReturnValue(mockQuery);

      const result = await service.findAll('user-1', 'token-123');

      expect(mockClient.from).toHaveBeenCalledWith('categories');
      expect(mockQuery.select).toHaveBeenCalledWith(
        '*, default_account:financial_accounts(id, name, color_hex, icon, account_type)',
      );
      expect(mockQuery.eq).toHaveBeenCalledWith('user_id', 'user-1');
      expect(mockQuery.eq).toHaveBeenCalledWith('is_archived', false);
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('Supermercado');
    });

    it('debe incluir categorías archivadas si includeArchived = true', async () => {
      const mockQuery: any = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        order: jest.fn().mockResolvedValue({
          data: [
            { id: 'cat-1', name: 'Activa', is_archived: false },
            { id: 'cat-2', name: 'Archivada', is_archived: true },
          ],
          error: null,
        }),
      };

      mockClient.from.mockReturnValue(mockQuery);

      const result = await service.findAll('user-1', 'token-123', true);

      expect(mockQuery.eq).toHaveBeenCalledWith('user_id', 'user-1');
      // No debe filtrar por is_archived = false
      expect(mockQuery.eq).not.toHaveBeenCalledWith('is_archived', false);
      expect(result).toHaveLength(2);
    });
  });

  describe('create', () => {
    it('debe insertar una nueva categoría', async () => {
      const insertQuery: any = {
        insert: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: {
            id: 'cat-new',
            name: 'Gimnasio',
            icon: 'fitness_center',
            color_hex: '#79ADDC',
            user_id: 'user-1',
          },
          error: null,
        }),
      };

      mockClient.from.mockReturnValue(insertQuery);

      const result = await service.create(
        'user-1',
        { name: 'Gimnasio', icon: 'fitness_center', color_hex: '#79ADDC' },
        'token-123',
      );

      expect(insertQuery.insert).toHaveBeenCalledWith({
        name: 'Gimnasio',
        icon: 'fitness_center',
        color_hex: '#79ADDC',
        user_id: 'user-1',
      });
      expect(result.name).toBe('Gimnasio');
    });

    it('debe lanzar ConflictException si el nombre ya existe (23505)', async () => {
      const insertQuery: any = {
        insert: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: null,
          error: { code: '23505', message: 'duplicate key' },
        }),
      };

      mockClient.from.mockReturnValue(insertQuery);

      await expect(
        service.create('user-1', { name: 'Supermercado' }, 'token-123'),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('archive', () => {
    it('debe marcar is_archived = true (CA-C1.3 soft delete)', async () => {
      const findQuery: any = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'cat-1' },
          error: null,
        }),
      };

      const updateQuery: any = {
        update: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'cat-1', is_archived: true },
          error: null,
        }),
      };

      mockClient.from.mockImplementation((table: string) => {
        if (findQuery.select.mock.calls.length === 0) {
          return findQuery;
        }
        return updateQuery;
      });

      const result = await service.archive('cat-1', 'user-1', 'token-123');

      expect(updateQuery.update).toHaveBeenCalledWith({ is_archived: true });
      expect(result.is_archived).toBe(true);
    });

    it('debe lanzar NotFoundException si no existe o no es de su propiedad', async () => {
      const findQuery: any = {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: null,
          error: { message: 'Not found' },
        }),
      };

      mockClient.from.mockReturnValue(findQuery);

      await expect(
        service.archive('cat-inexistente', 'user-1', 'token-123'),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
