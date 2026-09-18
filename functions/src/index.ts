import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { healthCheck } from './triggers/https/healthCheck';
