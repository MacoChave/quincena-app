import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseService } from '../../supabase/supabase.service';
import { ConfirmReceiptScanDto } from './dto/confirm-receipt-scan.dto';

const RECEIPT_SCANS_BUCKET = 'receipt-scans';

@Injectable()
export class ReceiptScansService {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly config: ConfigService,
  ) {}

  async findOne(id: string, userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { data, error } = await client
      .from('receipt_scans')
      .select('*')
      .eq('id', id)
      .eq('user_id', userId)
      .single();

    if (error || !data)
      throw new NotFoundException('Comprobante no encontrado');
    return data;
  }

  async findAllByUser(userId: string, accessToken: string) {
    const client = this.supabase.getAuthenticatedClient(accessToken);
    const { data, error } = await client
      .from('receipt_scans')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(50);

    if (error) throw new Error(error.message);
    return data;
  }

  /**
   * Sube un archivo de comprobante al bucket de Supabase Storage.
   * El archivo llega como Buffer desde el controlador (multipart/form-data).
   * Devuelve el scan record creado con estado 'pending'.
   *
   * NOTA: La extracción OCR real se haría aquí llamando a un servicio externo
   * (Google Cloud Vision, AWS Textract, etc.) o a un worker en background.
   * Por ahora se crea el registro con ocr_status='pending'.
   */
  async uploadAndCreateScan(
    userId: string,
    file: Express.Multer.File,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    // Construir ruta única: userId/timestamp-filename
    const ext = file.originalname.split('.').pop() ?? 'jpg';
    const storagePath = `${userId}/${Date.now()}.${ext}`;

    // Subir a Supabase Storage
    const { error: uploadError } = await client.storage
      .from(RECEIPT_SCANS_BUCKET)
      .upload(storagePath, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });

    if (uploadError) {
      throw new BadRequestException(
        `Error al subir el archivo: ${uploadError.message}`,
      );
    }

    // Crear registro del scan con estado 'pending'
    const { data, error } = await client
      .from('receipt_scans')
      .insert({
        user_id: userId,
        storage_path: storagePath,
        ocr_status: 'pending',
      })
      .select()
      .single();

    if (error) throw new Error(error.message);

    return {
      scan: data,
      message:
        'Comprobante subido exitosamente. El procesamiento OCR está en curso.',
    };
  }

  /**
   * Confirma el scan OCR y crea la transacción correspondiente (CA-03.2).
   * El usuario valida/corrige los datos extraídos antes de confirmar.
   * Nunca se guarda un gasto de forma ciega (CA-03.2).
   */
  async confirmAndCreateTransaction(
    scanId: string,
    userId: string,
    dto: ConfirmReceiptScanDto,
    accessToken: string,
  ) {
    const client = this.supabase.getAuthenticatedClient(accessToken);

    const scan = await this.findOne(scanId, userId, accessToken);

    if (scan.ocr_status === 'failed') {
      throw new BadRequestException(
        'El comprobante OCR falló. Por favor ingresa los datos manualmente.',
      );
    }

    // Resolver valores: preferir los del DTO (corrección usuario) sobre los del OCR
    const merchant = dto.merchant_name ?? scan.extracted_merchant;
    const amount = dto.amount ?? scan.extracted_amount;
    const txDate =
      dto.transaction_date ??
      (scan.extracted_date
        ? new Date(scan.extracted_date).toISOString().split('T')[0]
        : new Date().toISOString().split('T')[0]);

    if (!merchant || !amount || !dto.cycle_id || !dto.source_account_id) {
      throw new BadRequestException(
        'Se requieren: merchant_name, amount, cycle_id y source_account_id para confirmar el gasto.',
      );
    }

    // Crear transacción con referencia al scan
    const { data: transaction, error: txError } = await client
      .from('transactions')
      .insert({
        user_id: userId,
        cycle_id: dto.cycle_id,
        allocation_id: dto.allocation_id ?? null,
        receipt_scan_id: scanId,
        source_account_id: dto.source_account_id,
        amount,
        merchant_name: merchant,
        transaction_date: txDate,
        transaction_type: 'expense',
        entry_method: 'ocr',
        notes: dto.notes ?? null,
      })
      .select()
      .single();

    if (txError) throw new Error(txError.message);

    // Marcar el scan como verificado
    await client
      .from('receipt_scans')
      .update({ ocr_status: 'verified' })
      .eq('id', scanId);

    return {
      transaction,
      scan_id: scanId,
      message: 'Gasto registrado exitosamente desde comprobante OCR.',
    };
  }
}
