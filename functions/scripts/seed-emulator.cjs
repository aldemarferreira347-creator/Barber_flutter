// Carga datos de PRUEBA en los emuladores (nunca en el proyecto real): un
// usuario por rol y una barbería de ejemplo con servicios, productos,
// citas, reseñas, compras y notificaciones. Es idempotente: se puede
// ejecutar varias veces.
//
// Uso (con `npm run emulators` corriendo): npm run seed
//
// Cuentas de prueba (solo existen en el emulador):
//   admin@barber.test · owner@barber.test · barber@barber.test · client@barber.test
//   contraseña de todas: Barber123!
process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= 'localhost:9099';
process.env.FIREBASE_STORAGE_EMULATOR_HOST ??= 'localhost:9199';

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp, GeoPoint } = require('firebase-admin/firestore');

initializeApp({ projectId: 'barber-5082f' });
const auth = getAuth();
const db = getFirestore();

const PASSWORD = 'Barber123!';
const DAY = 24 * 60 * 60 * 1000;
const now = Date.now();
const at = (offsetMs) => Timestamp.fromMillis(now + offsetMs);
const atHour = (dayOffset, hour, minute = 0) => {
  const d = new Date(now + dayOffset * DAY);
  d.setHours(hour, minute, 0, 0);
  return Timestamp.fromDate(d);
};

const schedule = Object.fromEntries(
  ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'].map((day) => [
    day,
    { isOpen: day !== 'domingo', openTime: '09:00', closeTime: day === 'sábado' ? '15:00' : '19:00' },
  ]),
);

const users = [
  { uid: 'admin1', email: 'admin@barber.test', name: 'Ada Admin', role: 'admin', phone: '+573000000001' },
  { uid: 'owner1', email: 'owner@barber.test', name: 'Oscar Dueño', role: 'owner', phone: '+573000000002' },
  { uid: 'barber1', email: 'barber@barber.test', name: 'Carlos Pérez', role: 'barber', phone: '+573000000003', barbershopId: 'shop1' },
  { uid: 'barber2', email: 'barber2@barber.test', name: 'Mateo Ríos', role: 'barber', phone: '+573000000004', barbershopId: 'shop1' },
  { uid: 'client1', email: 'client@barber.test', name: 'Juan Pérez', role: 'client', phone: '+573000000005' },
  { uid: 'client2', email: 'client2@barber.test', name: 'Laura Gómez', role: 'client', phone: '+573000000006' },
];

async function seedUsers() {
  for (const u of users) {
    try {
      await auth.deleteUser(u.uid);
    } catch (_) {
      /* no existía */
    }
    await auth.createUser({ uid: u.uid, email: u.email, password: PASSWORD, displayName: u.name });
    await db.doc(`users/${u.uid}`).set({
      uid: u.uid,
      email: u.email,
      name: u.name,
      phone: u.phone,
      role: u.role,
      barbershopId: u.barbershopId ?? null,
      active: true,
      available: true,
      createdAt: at(-30 * DAY),
      notificationTone: 'normal',
      fcmTokens: [],
    });
  }
}

async function seedShops() {
  await db.doc('barbershops/shop1').set({
    name: 'Barbería Central',
    ownerId: 'owner1',
    address: 'Calle 123 #45-67, Bogotá',
    location: new GeoPoint(4.711, -74.0721),
    phone: '+573000000010',
    email: 'central@barber.test',
    description: 'Cortes clásicos, barba y afeitado con toalla caliente. Atención con cita.',
    photoUrl: null,
    active: true,
    approvalStatus: 'approved',
    paymentStatus: 'ok',
    paymentDueDate: at(18 * DAY),
    schedule,
    ratingSum: 27,
    ratingCount: 6,
  });
  await db.doc('barbershops/shop2').set({
    name: 'Barbería Norte',
    ownerId: 'owner1',
    address: 'Carrera 15 #93-20, Bogotá',
    location: new GeoPoint(4.678, -74.048),
    phone: '+573000000011',
    email: 'norte@barber.test',
    description: 'Sede nueva, pendiente de aprobación.',
    photoUrl: null,
    active: false,
    approvalStatus: 'pending',
    paymentStatus: 'ok',
    paymentDueDate: null,
    schedule,
  });

  const services = [
    ['svc1', 'Corte clásico', 25000, 30],
    ['svc2', 'Barba', 15000, 20],
    ['svc3', 'Corte + Barba', 35000, 45],
  ];
  for (const [id, name, price, durationMinutes] of services) {
    await db.doc(`barbershops/shop1/services/${id}`).set({
      name,
      description: `${name} profesional`,
      price,
      durationMinutes,
      photoUrl: null,
      active: true,
    });
  }
  const products = [
    ['prod1', 'Cera para peinar', 18000],
    ['prod2', 'Aceite para barba', 25000],
    ['prod3', 'Shampoo premium', 22000],
  ];
  for (const [id, name, price] of products) {
    await db.doc(`barbershops/shop1/products/${id}`).set({
      name,
      description: `${name} de uso profesional`,
      price,
      photoUrl: null,
      active: true,
    });
  }
}

async function seedAppointments() {
  const base = {
    barbershopId: 'shop1',
    barberId: 'barber1',
    barberName: 'Carlos Pérez',
    clientId: 'client1',
    clientName: 'Juan Pérez',
    durationMinutes: 30,
    createdAt: at(-5 * DAY),
    rescheduleHistory: [],
    forcedRatingPenalty: false,
  };
  const appts = [
    { id: 'apptUpcoming', serviceId: 'svc1', serviceName: 'Corte clásico', servicePrice: 25000, date: atHour(1, 10), status: 'accepted', paid: true, paymentId: 'payUpcoming' },
    { id: 'apptPending', serviceId: 'svc2', serviceName: 'Barba', servicePrice: 15000, date: atHour(3, 16), status: 'pending', paid: false },
    { id: 'apptDone1', serviceId: 'svc3', serviceName: 'Corte + Barba', servicePrice: 35000, date: atHour(-6, 11), status: 'completed', paid: true, paymentId: 'payDone1' },
    { id: 'apptDone2', serviceId: 'svc1', serviceName: 'Corte clásico', servicePrice: 25000, date: atHour(-14, 15), status: 'completed', paid: true, paymentId: 'payDone2' },
    { id: 'apptCancelled', serviceId: 'svc2', serviceName: 'Barba', servicePrice: 15000, date: atHour(-3, 9), status: 'cancelled', paid: false },
    { id: 'apptOther', clientId: 'client2', clientName: 'Laura Gómez', barberId: 'barber2', barberName: 'Mateo Ríos', serviceId: 'svc1', serviceName: 'Corte clásico', servicePrice: 25000, date: atHour(2, 12), status: 'pending', paid: false },
  ];
  for (const { id, ...rest } of appts) {
    await db.doc(`appointments/${id}`).set({ ...base, ...rest });
  }
  for (const [id, relatedId, amount] of [
    ['payUpcoming', 'apptUpcoming', 25000],
    ['payDone1', 'apptDone1', 35000],
    ['payDone2', 'apptDone2', 25000],
  ]) {
    await db.doc(`payments/${id}`).set({
      payerId: 'client1',
      amount,
      category: 'appointment',
      relatedId,
      description: 'Cita en barbershops/shop1',
      status: 'approved',
      createdAt: at(-7 * DAY),
      resolvedAt: at(-7 * DAY),
      refundedAmount: null,
    });
  }
}

async function seedFeedback() {
  const comments = [
    ['apptDone1', 'Excelente corte y muy puntual. Volveré.', 'Juan Pérez'],
    ['apptDone2', 'Muy buena atención, el ambiente es genial.', 'Juan Pérez'],
  ];
  for (const [id, text, clientName] of comments) {
    await db.doc(`comments/${id}`).set({
      appointmentId: id,
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      clientName,
      text,
      photoUrl: null,
      status: 'published',
      createdAt: at(-5 * DAY),
      replyText: null,
      replyAt: null,
      repliedByBarberId: null,
    });
    await db.doc(`ratings/${id}`).set({
      appointmentId: id,
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      barberStars: 5,
      shopStars: 4,
      effectiveShopStars: 4,
      forcedRatingPenaltyApplied: false,
      createdAt: at(-5 * DAY),
    });
  }
}

async function seedPurchasesAndNotifications() {
  await db.doc('payments/payProd1').set({
    payerId: 'client1',
    amount: 36000,
    category: 'product',
    relatedId: 'purchase1',
    description: 'Compra en barbershops/shop1',
    status: 'approved',
    createdAt: at(-2 * 60 * 60 * 1000),
    resolvedAt: at(-2 * 60 * 60 * 1000),
    refundedAmount: null,
  });
  await db.doc('purchases/purchase1').set({
    barbershopId: 'shop1',
    buyerId: 'client1',
    appointmentId: null,
    items: [{ productId: 'prod1', productName: 'Cera para peinar', unitPrice: 18000, quantity: 2, refunded: false }],
    totalAmount: 36000,
    paymentId: 'payProd1',
    claimCode: 'A1B2C3D4',
    status: 'pending_claim',
    createdAt: at(-2 * 60 * 60 * 1000),
    claimedAt: null,
    expiresAt: at(22 * 60 * 60 * 1000),
  });

  const notifications = [
    ['Tu cita fue confirmada', 'Carlos te espera mañana a las 10:00 a. m. en Barbería Central.', false, -3 * 60 * 60 * 1000],
    ['Recuerda reclamar tu compra', 'Tienes 22 horas para reclamar tus productos con el código A1B2C3D4.', false, -2 * 60 * 60 * 1000],
    ['Bienvenido a BarberFlow', 'Explora barberías y agenda tu primera cita.', true, -20 * DAY],
  ];
  for (const [i, [title, body, read, offset]] of notifications.entries()) {
    await db.doc(`notifications/n${i + 1}`).set({
      toUserId: 'client1',
      title,
      body,
      type: 'manual',
      read,
      createdAt: at(offset),
    });
  }
}

(async () => {
  await seedUsers();
  await seedShops();
  await seedAppointments();
  await seedFeedback();
  await seedPurchasesAndNotifications();
  console.log('Datos de prueba cargados en los emuladores.');
  console.log('Cuentas: admin@ / owner@ / barber@ / client@barber.test — contraseña: ' + PASSWORD);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
