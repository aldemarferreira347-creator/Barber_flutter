import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { healthCheck } from './triggers/https/healthCheck';
export { sendNotification } from './triggers/https/sendNotification';
export { requestPayment } from './triggers/https/requestPayment';
export { refundPayment } from './triggers/https/refundPayment';
export { createPurchase } from './triggers/https/createPurchase';
export { claimPurchase } from './triggers/https/claimPurchase';
export { refundPurchaseItems } from './triggers/https/refundPurchaseItems';
export { expirePurchases } from './triggers/scheduled/expirePurchases';
export { bookPaidAppointment } from './triggers/https/bookPaidAppointment';
export { postponeAppointment } from './triggers/https/postponeAppointment';
export { requestAppointmentRefund } from './triggers/https/requestAppointmentRefund';
export { resolveAppointmentRefund } from './triggers/https/resolveAppointmentRefund';
export { sendAppointmentReminders } from './triggers/scheduled/sendAppointmentReminders';
export { markBarberAway } from './triggers/https/markBarberAway';
export { markBarberReturned } from './triggers/https/markBarberReturned';
export { processOverdueBarbers } from './triggers/scheduled/processOverdueBarbers';
export { closeShopForExternalEvent } from './triggers/https/closeShopForExternalEvent';
export { submitAppointmentRating } from './triggers/https/submitAppointmentRating';
export { submitAppointmentComment } from './triggers/https/submitAppointmentComment';
export { replyToComment } from './triggers/https/replyToComment';
export { requestBarbershopOwnership } from './triggers/https/requestBarbershopOwnership';
export { payBarbershopSubscription } from './triggers/https/payBarbershopSubscription';
export { cancelBarbershopSubscription } from './triggers/https/cancelBarbershopSubscription';
export { processBarbershopBilling } from './triggers/scheduled/processBarbershopBilling';
