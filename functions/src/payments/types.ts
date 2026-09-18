export type PaymentCategory = 'appointment' | 'product' | 'subscription';

/** No confundir con el estado de la MENSUALIDAD de una barbería (ok/overdue/blocked). */
export type PaymentIntentStatus = 'pending' | 'approved' | 'rejected' | 'refunded';

export interface RequestPaymentInput {
  payerId: string;
  amount: number;
  category: PaymentCategory;
  relatedId: string;
  description: string | null;
}

/**
 * Cualquier pasarela de pago (Nequi u otra, real o simulada) implementa
 * esta interfaz. El resto del backend depende solo de ella — cambiar de
 * proveedor es escribir una clase nueva, nunca tocar quien la usa.
 */
export interface PaymentGatewayAdapter {
  /** Crea la solicitud de pago y devuelve el id del documento payments/{id}. */
  requestPayment(input: RequestPaymentInput): Promise<string>;

  /** Reembolsa total (si se omite `amount`) o parcialmente un pago ya aprobado. */
  refund(paymentId: string, amount?: number): Promise<void>;
}
