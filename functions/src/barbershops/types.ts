export interface RequestOwnershipInput {
  barbershopId: string;
  requestedBy: string;
}

export interface PaySubscriptionInput {
  barbershopId: string;
  requestedBy: string;
}

export interface CancelSubscriptionInput {
  barbershopId: string;
  requestedBy: string;
}
