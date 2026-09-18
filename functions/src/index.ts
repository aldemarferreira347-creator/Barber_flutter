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
