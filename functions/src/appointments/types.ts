export type RefundRequestStatus = 'pending' | 'approved' | 'rejected';

export interface BookPaidAppointmentInput {
  clientId: string;
  clientName: string;
  barbershopId: string;
  barberId: string;
  barberName: string;
  serviceId: string;
  date: Date;
}

export interface RequestAppointmentRefundInput {
  appointmentId: string;
  clientId: string;
  reason: string;
  purchaseId: string | null;
  purchaseItemIndexes: number[] | null;
}
