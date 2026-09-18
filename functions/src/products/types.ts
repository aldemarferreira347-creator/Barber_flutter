export type PurchaseStatus = 'pending_payment' | 'pending_claim' | 'claimed' | 'expired' | 'payment_failed';

export interface PurchaseItemInput {
  productId: string;
  quantity: number;
}

export interface PurchaseItemRecord {
  productId: string;
  productName: string;
  unitPrice: number;
  quantity: number;
  refunded: boolean;
}

export interface CreatePurchaseInput {
  buyerId: string;
  barbershopId: string;
  items: PurchaseItemInput[];
  appointmentId: string | null;
}
