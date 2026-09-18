/** Tono elegido por el usuario para el contenido de sus notificaciones (spec 3.5). */
export type NotificationTone = 'formal' | 'normal' | 'friendly' | 'informal';

/** Subconjunto de users/{uid} que necesita el sistema de notificaciones. */
export interface NotificationRecipient {
  uid: string;
  fcmTokens: string[];
  phone: string | null;
  email: string | null;
  notificationTone: NotificationTone;
}

export interface NotificationMessage {
  title: string;
  body: string;
}

export type ChannelResult = 'sent' | 'skipped';

/**
 * Un canal de entrega (push, SMS, correo...). El dispatcher solo conoce esta
 * interfaz — agregar un canal nuevo es una clase nueva que se suma a la
 * lista del dispatcher, nunca requiere tocar los canales existentes
 * (Open/Closed) ni el propio dispatcher.
 */
export interface NotificationChannel {
  readonly name: string;
  send(recipient: NotificationRecipient, message: NotificationMessage): Promise<ChannelResult>;
}

/**
 * Categoría de la notificación: controla solo el ícono/estilo en el cliente
 * (ver lib/models/app_notification.dart) — no la vía de entrega, que decide
 * el dispatcher según canales disponibles.
 */
export type NotificationCategory = 'manual' | 'auto_payment_overdue';

export interface DispatchNotificationInput {
  toUserId: string;
  title: string;
  body: string;
  category: NotificationCategory;
}
