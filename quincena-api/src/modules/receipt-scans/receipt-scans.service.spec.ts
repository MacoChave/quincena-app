import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { ReceiptScansService } from './receipt-scans.service';
import { SupabaseService } from '../../supabase/supabase.service';

describe('ReceiptScansService', () => {
  let service: ReceiptScansService;
  let mockSupabaseService: any;
  let mockClient: any;
  let mockStorage: any;
  let mockBucket: any;

  beforeEach(async () => {
    mockBucket = {
      upload: jest.fn().mockResolvedValue({ data: { path: 'path' }, error: null }),
    };

    mockStorage = {
      from: jest.fn().mockReturnValue(mockBucket),
    };

    mockClient = {
      storage: mockStorage,
      from: jest.fn().mockReturnValue({
        insert: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'scan-1', storage_path: 'user-1/123.jpg', ocr_status: 'pending' },
          error: null,
        }),
      }),
    };

    mockSupabaseService = {
      getAuthenticatedClient: jest.fn().mockReturnValue(mockClient),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReceiptScansService,
        { provide: SupabaseService, useValue: mockSupabaseService },
        { provide: ConfigService, useValue: { get: jest.fn() } },
      ],
    }).compile();

    service = module.get<ReceiptScansService>(ReceiptScansService);
  });

  it('debe subir comprobantes al bucket "receipts"', async () => {
    const mockFile: any = {
      originalname: 'recibo.jpg',
      mimetype: 'image/jpeg',
      buffer: Buffer.from('fake-image-bytes'),
    };

    const result = await service.uploadAndCreateScan('user-1', mockFile, 'mock-token');

    expect(mockStorage.from).toHaveBeenCalledWith('receipts');
    expect(mockBucket.upload).toHaveBeenCalledWith(
      expect.stringMatching(/^user-1\/\d+\.jpg$/),
      mockFile.buffer,
      expect.objectContaining({ contentType: 'image/jpeg' }),
    );
    expect(result.scan.ocr_status).toBe('pending');
  });
});
