# Especificación de Funcionalidades
## App de Gestión de Barbería — Plataforma Multi-Barbería

*Documento de especificación funcional de requisitos*
*Stack: Flutter + Firebase · Pasarela de pago: Nequi*

---

## 1. Introducción

Este documento organiza y describe, de forma funcional y sin detalle de implementación técnica, todas las funcionalidades definidas para la aplicación de gestión de barbería. La plataforma opera bajo un modelo multi-barbería: no gestiona una sola barbería, sino múltiples barberías independientes entre sí, cada una con su propio dueño, sus propios barberos y su propia suscripción mensual, todas administradas de forma centralizada por un administrador general.

Cada apartado describe el objetivo de la funcionalidad, su comportamiento desde la perspectiva del usuario y las reglas de negocio que la gobiernan, como base para el diseño técnico y el desarrollo posterior.

---

## 2. Roles de usuario

El sistema define cuatro roles, cada uno con un nivel de acceso distinto. El rol no otorga automáticamente permisos de gestión — en el caso del rol Dueño, los permisos reales dependen de tener al menos una barbería aprobada y configurada.

### 2.1 Cliente
Usuario final de la app. Puede explorar barberías disponibles, reservar citas, comprar productos, calificar y comentar servicios, y personalizar el tono de sus notificaciones.

### 2.2 Barbero
Pertenece a una barbería específica. Gestiona su disponibilidad (estado en tienda/fuera de tienda), marca servicios como completados, responde comentarios de clientes, y valida códigos de reclamo de productos y de reembolsos.

### 2.3 Dueño de barbería
Puede solicitar y administrar una o varias barberías, cada una de forma completamente independiente (información, suscripción, barberos, productos y reportes propios). Tiene visibilidad total de la actividad dentro de cada una de sus barberías: qué hizo cada barbero, qué pedidos se reclamaron, qué clientes asistieron, y reportes generales de operación. Gestiona productos, servicios y aprueba o rechaza solicitudes de reembolso.

### 2.4 Administrador
Rol único del propietario de la plataforma. Tiene visibilidad y control sobre todas las barberías registradas y todos los usuarios del sistema, en un apartado de "Gestión de barberías". Aprueba o rechaza solicitudes para convertirse en dueño, y gestiona el estado de la mensualidad de cada barbería.

---

## 3. Notificaciones

### 3.1 Sistema de notificaciones push
**Objetivo:** Permitir comunicación directa e inmediata con el usuario a través de notificaciones nativas en su teléfono, reutilizando un mismo mecanismo base para todos los tipos de notificación del sistema, de forma que agregar un nuevo tipo de notificación en el futuro no afecte ni ponga en riesgo las que ya existen.

**Descripción funcional**
- Todas las notificaciones del sistema (recordatorios, alertas de disponibilidad del barbero, cierres de tienda, respuestas a comentarios, resultados de reembolso, etc.) se procesan bajo un mismo flujo estándar y reutilizable.
- Centro de notificaciones dentro de la app para consultar el historial de notificaciones recibidas.
- Canal de respaldo por SMS o correo para los casos en los que el usuario tenga la app cerrada, sin permisos de notificación o no pueda recibir el push por cualquier motivo.

### 3.2 Recordatorios de cita
**Objetivo:** Reducir inasistencias recordando al usuario su cita próxima.

**Descripción funcional**
- Notificación automática 1 hora antes de la cita.
- Notificación automática 15 minutos antes de la cita.

### 3.3 Seguimiento de disponibilidad del barbero
**Objetivo:** Evitar que el cliente pierda su viaje a la barbería cuando el barbero se encuentra fuera del establecimiento cerca de la hora de una reserva.

**Descripción funcional**
- El barbero cuenta con un control para marcar su salida de la tienda, indicando cuánto tiempo estima que tardará en volver.
- El barbero cuenta con un control para marcar su regreso.
- Si el barbero vuelve dentro del tiempo estimado y hay una reserva próxima (dentro de la siguiente hora), se notifica al cliente que la cita sigue en pie con normalidad.
- Si el barbero no marca su regreso dentro del tiempo que él mismo estimó, todas sus reservas pagadas de esa tarde se marcan automáticamente como aplazadas, y se invita a cada cliente afectado a reprogramar su cita.

**Reglas de negocio**
- El tiempo límite no es un valor fijo igual para todos los casos: se calcula sobre el propio estimado que el barbero declaró al salir de la tienda.

### 3.4 Cierre de tienda por evento externo
**Objetivo:** Informar oportunamente a los clientes con reservas pagadas cuando la barbería debe cerrar por un motivo externo, y resolver la consecuencia sobre esas reservas.

**Descripción funcional**
- Notificación a todos los clientes con reservas pagadas afectadas por el cierre.
- Apertura automática del flujo de posponer cita para cada reserva afectada (ver 6.4).

**Reglas de negocio**
- Se descuenta obligatoriamente 1 estrella de la calificación final asociada a esa reserva, ya que el cierre externo afecta la experiencia del cliente aunque no dependa de la barbería.

### 3.5 Personalización del tono de notificaciones
**Objetivo:** Permitir que cada usuario reciba las notificaciones del sistema en el estilo de comunicación con el que se sienta más identificado.

**Descripción funcional**
- Al iniciar por primera vez, el usuario elige el tono en el que prefiere recibir sus notificaciones: formal, normal, amigable o informal/coloquial.
- Esta preferencia se puede modificar en cualquier momento desde la configuración del perfil.
- El contenido de cada notificación se redacta según el tono elegido, manteniendo el mismo significado e información en todos los casos.

**Reglas de negocio**
- Esta personalización aplica únicamente a las notificaciones del sistema — no modifica el resto de la interfaz de la app (menús, botones, pantallas), que se mantiene igual para todos los usuarios.

---

## 4. Interfaz y experiencia de usuario

### 4.1 Corrección de vistas e historial
**Objetivo:** Mejorar la usabilidad y consistencia visual de las pantallas existentes, en particular el apartado de historial.

**Descripción funcional**
- Revisión general de las vistas actuales para corregir errores de presentación.
- Rediseño del apartado de historial de citas y servicios del usuario.

### 4.2 Identidad visual
**Objetivo:** Dar identidad visual propia a la aplicación.

**Descripción funcional**
- Incorporación de logo en splash screen, ícono de la app y encabezados principales.

---

## 5. Autenticación

### 5.1 Autenticación con Google
**Objetivo:** Ofrecer al usuario una forma de registro e inicio de sesión más rápida y sencilla, como alternativa al registro tradicional con correo y contraseña.

**Descripción funcional**
- El usuario puede registrarse o iniciar sesión usando directamente su cuenta de Gmail, sin necesidad de crear ni recordar una contraseña adicional.
- Ambos métodos (correo/contraseña y Google) conviven en la misma pantalla de acceso.

**Reglas de negocio**
- Si un usuario ya tiene una cuenta creada con correo y contraseña, y luego intenta ingresar con Google usando ese mismo correo, el sistema exige primero confirmar la contraseña original antes de vincular ambos métodos a la misma cuenta. Esto evita que alguien pueda apropiarse de una cuenta ajena solo por conocer o coincidir en el correo.

---

## 6. Citas y reservas

### 6.1 Tipos de reserva
**Objetivo:** Ofrecer dos formas de agendar, según el nivel de compromiso del cliente.

**Descripción funcional**
- Reserva sin pago: el cliente simplemente indica la intención de asistir a una hora determinada. No representa ningún compromiso formal y no otorga ninguna prioridad ni bloquea el horario para otros clientes.
- Reserva pagada: el cliente paga por el servicio (y opcionalmente productos adicionales, como tintes u otros artículos) al momento de reservar. Sí bloquea el horario correspondiente, garantizando que nadie más pueda tomarlo.

### 6.2 Disponibilidad de horarios
**Objetivo:** Evitar que dos clientes terminen ocupando, por error, el mismo horario de una reserva pagada.

**Descripción funcional**
- Cuando dos clientes intentan tomar el mismo horario al mismo tiempo, el sistema garantiza que solo uno de los dos consiga la reserva.
- Al cliente que no logró completar la reserva se le informa que ese horario ya no está disponible y se le invita a elegir otro.

**Reglas de negocio**
- Esta validación de disponibilidad solo aplica a reservas pagadas — las reservas sin pago no bloquean horarios entre sí.

### 6.3 Cancelación de reservas
**Objetivo:** Definir el efecto de cancelar una reserva según su tipo.

**Descripción funcional**
- Reserva sin pago: cancelar no tiene ninguna consecuencia, el horario simplemente queda libre.
- Reserva pagada: cancelar dirige primero al cliente hacia la opción de posponer la cita a una hora que sí le funcione, en lugar de perder el pago directamente.
- Si el cliente insiste en cancelar (no reprogramar) una reserva pagada, debe indicar una justificación, que es revisada y aprobada por el dueño de la barbería antes de proceder con el reembolso.

### 6.4 Posponer cita
**Objetivo:** Permitir reprogramar una cita ya pagada sin necesidad de cancelarla ni perder el pago realizado.

**Descripción funcional**
- El cliente selecciona una nueva fecha y hora disponible, conservando el pago ya efectuado.
- Queda un historial que vincula la nueva fecha con la reserva original.

**Reglas de negocio**
- Se activa automáticamente en los casos de cierre de tienda por evento externo (3.4) y de ausencia prolongada del barbero (3.3), y también puede iniciarse de forma manual por el cliente.

### 6.5 Reembolsos
**Objetivo:** Definir cómo se gestiona la devolución de dinero cuando una reserva pagada se cancela.

**Descripción funcional**
- El dueño de la barbería revisa y aprueba o rechaza cada solicitud de reembolso, verificando que la justificación sea válida.
- La devolución puede entregarse de forma digital (mismo medio de pago) o presencial en efectivo, según se acuerde.
- Cuando la reserva incluye productos adicionales junto con el servicio, el cliente puede elegir mediante un checklist qué ítems específicos desea reembolsar y cuáles prefiere conservar.

### 6.6 Reservas y disponibilidad de la barbería
**Objetivo:** Permitir que los clientes reserven libremente hacia el futuro, sin restringir la reserva únicamente al período ya pagado de la mensualidad de la barbería.

**Descripción funcional**
- Un cliente puede agendar una cita en cualquier fecha futura disponible, sin importar si esa fecha cae después del próximo corte de mensualidad de la barbería.

**Reglas de negocio**
- Si la fecha de una reserva cae después del corte de mensualidad y la barbería efectivamente no renueva a tiempo, esa reserva puntual se cancela automáticamente con reembolso al cliente, solo en ese caso excepcional (ver sección 12.6).

---

## 7. Calificaciones y comentarios

### 7.1 Calificación por estrellas
**Objetivo:** Permitir que el cliente evalúe la calidad del servicio recibido.

**Descripción funcional**
- Calificación de 1 a 5 estrellas al barbero que atendió el servicio.
- Calificación de 1 a 5 estrellas a la barbería en general.

**Reglas de negocio**
- Solo se puede calificar y comentar una reserva que ya fue pagada, asistida y confirmada como completada — garantizando que quien califica realmente usó el servicio.
- Si el cliente no deja calificación, ese servicio simplemente no se incluye en el cálculo del promedio; no se le asigna ninguna calificación automática por defecto.

### 7.2 Comentarios sobre el servicio
**Objetivo:** Permitir retroalimentación más detallada, junto con evidencia visual del resultado.

**Descripción funcional**
- El cliente puede escribir un comentario y adjuntar una foto del resultado del servicio.
- El barbero puede responder cualquier comentario recibido, ya sea dirigido a él o a la barbería en general.

**Reglas de negocio**
- Dejar comentario es opcional; no comentar no afecta la calificación por estrellas ya registrada.

### 7.3 Moderación de contenido
**Objetivo:** Evitar que los comentarios contengan lenguaje ofensivo, groserías o contenido inapropiado.

**Descripción funcional**
- Todo comentario pasa por una revisión automática antes de publicarse.
- Un comentario que sea detectado como inapropiado es rechazado y no llega a publicarse.
- La misma revisión aplica a las observaciones en texto libre del apartado de recomendación de peinados (sección 9.2).

### 7.4 Lineamientos de conducta
**Objetivo:** Guiar tanto a barberías como a clientes sobre qué se espera de cada parte al momento de evaluar el servicio.

**Descripción funcional**
- Se muestra al cliente, antes o durante el proceso de calificar, información sobre qué debe garantizar la barbería (puntualidad, higiene, trato) y qué se espera de un comentario constructivo por parte del cliente.

---

## 8. Geolocalización

### 8.1 Redirección a Google Maps
**Objetivo:** Facilitar que el cliente llegue físicamente a la barbería.

**Descripción funcional**
- Botón que abre Google Maps con la ubicación exacta de la barbería seleccionada.

---

## 9. Recomendación de peinados con Inteligencia Artificial

### 9.1 Análisis facial
**Objetivo:** Analizar la foto del usuario para identificar su forma de rostro y rasgos relevantes, como base de la recomendación.

**Descripción funcional**
- El usuario sube una foto de su rostro.
- El sistema identifica la forma de rostro y rasgos como mandíbula, frente, entradas, densidad y textura del cabello.

### 9.2 Personalización de la recomendación
**Objetivo:** Permitir que el usuario oriente el tipo de resultado que recibe.

**Descripción funcional**
- Filtros opcionales de preferencia: largo de cabello, tipo de estilo, entre otros.
- Campo de observación libre donde el usuario puede indicar particularidades (por ejemplo, entradas pronunciadas, o que no quiere cierto tipo de corte).

**Reglas de negocio**
- Tanto los filtros como la observación son opcionales; si no se indican, la recomendación se basa únicamente en el análisis facial.

### 9.3 Recomendaciones con puntaje de compatibilidad
**Objetivo:** Entregar al usuario una o varias opciones de corte, indicando qué tan bien se ajustan a su rostro.

**Descripción funcional**
- Cada estilo recomendado incluye un puntaje del 1 al 10 según qué tan bien se ajusta estructuralmente a la forma de rostro del usuario.
- Se explica con qué aspectos de su rostro armoniza ese corte.
- Cuando un estilo no es favorable, se explica con qué aspecto de su rostro podría no armonizar, siempre en términos de la estructura del corte, nunca como un juicio sobre la persona.

**Reglas de negocio**
- El puntaje se basa en compatibilidad estructural (forma y proporciones del rostro), no en una valoración de atractivo personal, para mantener un tono siempre respetuoso y objetivo hacia el usuario.

### 9.4 Referencia visual del resultado
**Objetivo:** Darle al usuario y al barbero una referencia visual de cómo se vería el corte recomendado, sin editar la foto personal del usuario.

**Descripción funcional**
- El resultado visual es una cabeza/maniquí genérico (no la foto real del usuario) con el peinado recomendado ya aplicado, sirviendo como referencia para el barbero al momento del servicio.
- El usuario puede rotar la vista del maniquí para observar el peinado desde distintos ángulos.

**Reglas de negocio**
- Las referencias visuales corresponden a un catálogo de diseños ya establecidos en el sistema (por forma de rostro y estilo), tomando los cortes más populares como base, en lugar de generar una imagen nueva cada vez que un usuario solicita una recomendación.

---

## 10. Productos

### 10.1 Catálogo de productos
**Objetivo:** Mostrar a los clientes los productos ofrecidos por cada barbería.

**Descripción funcional**
- Catálogo con imagen, nombre, descripción y precio de cada producto.

### 10.2 Gestión de productos
**Objetivo:** Permitir la administración del catálogo por parte del personal autorizado de cada barbería.

**Descripción funcional**
- Creación, edición, consulta y eliminación de productos desde el panel de la barbería.

### 10.3 Formas de compra
**Objetivo:** Ofrecer dos formas de adquirir un producto.

**Descripción funcional**
- Vinculado a una cita: el producto se agrega como parte de una reserva ya existente (por ejemplo, un tinte junto con el corte).
- Compra directa: el cliente adquiere el producto sin necesidad de tener una reserva.

### 10.4 Reclamo de productos comprados
**Objetivo:** Garantizar una entrega controlada y verificable de los productos comprados.

**Descripción funcional**
- Cada compra genera un código único, asociado a toda la compra (no a cada producto por separado).
- El cliente presenta ese código en la barbería para reclamar sus productos.
- El cliente cuenta con 24 horas desde la compra para reclamar sus productos con ese código.

**Reglas de negocio**
- Pasado ese plazo sin reclamo, la barbería queda liberada de responsabilidad sobre esos productos.

### 10.5 Reembolso de productos
**Objetivo:** Vincular el proceso de reembolso de productos con el mismo código de reclamo, evitando inconsistencias entre lo entregado y lo devuelto.

**Descripción funcional**
- Al procesar un reembolso, el cliente indica en un checklist qué productos de su compra desea reembolsar.
- El barbero, usando el mismo código de la compra, puede consultar y verificar qué ítems de esa compra ya fueron reembolsados, evitando que se entregue un producto que ya fue devuelto o pagado en efectivo por error.

---

## 11. Fotos

### 11.1 Captura de fotos desde la app
**Objetivo:** Permitir tomar fotos directamente desde la cámara del dispositivo, sin salir de la aplicación.

**Descripción funcional**
- Acceso a la cámara del dispositivo para adjuntar imágenes en los flujos correspondientes: comentarios de servicio, recomendación de peinados, entre otros.

---

## 12. Gestión multi-barbería

### 12.1 Solicitud para ser dueño de barbería
**Objetivo:** Permitir que un cliente solicite convertirse en dueño y registrar su propia barbería en la plataforma.

**Descripción funcional**
- El usuario envía una solicitud indicando los datos de la barbería que desea registrar.
- El rol del usuario cambia a "dueño" apenas envía la solicitud.
- El administrador revisa y aprueba o rechaza la solicitud.

**Reglas de negocio**
- Tener el rol "dueño" sin una barbería aprobada no otorga ningún permiso de gestión adicional — el usuario sigue viendo y usando la app exactamente igual que un cliente hasta que su solicitud sea aprobada.
- Una vez aprobada, se habilita el panel de gestión de esa barbería específicamente.

### 12.2 Múltiples barberías por dueño
**Objetivo:** Permitir que un mismo dueño administre más de una barbería.

**Descripción funcional**
- Un dueño puede solicitar y tener registradas varias barberías bajo su cuenta.
- Cada barbería es completamente independiente: tiene su propia información (ubicación, fotos, logo, servicios, productos), su propia suscripción mensual y su propio estado, sin relación entre unas y otras.

**Reglas de negocio**
- Cada barbería nueva requiere una configuración inicial completa (ubicación, fotos, características, servicios) antes de poder aparecer en el catálogo visible para los clientes.

### 12.3 Panel del dueño
**Objetivo:** Darle al dueño visibilidad y control total sobre cada una de sus barberías.

**Descripción funcional**
- Actividad de cada barbero: servicios atendidos, estado de disponibilidad, historial.
- Pedidos y reclamos de productos.
- Clientes atendidos y reportes generales de operación.
- Gestión de productos y servicios ofrecidos.
- Aprobación o rechazo de solicitudes de reembolso.

### 12.4 Panel del administrador
**Objetivo:** Darle al administrador de la plataforma visibilidad y control sobre el conjunto completo de barberías y usuarios.

**Descripción funcional**
- Apartado "Gestión de barberías": listado y control de todas las barberías registradas en la plataforma.
- Gestión de usuarios a nivel general.
- Control del estado de la mensualidad de cada barbería: cuáles están al día y cuáles no.
- Aprobación o rechazo de solicitudes para convertirse en dueño de barbería.

### 12.5 Mensualidad y suscripción
**Objetivo:** Definir cómo se mantiene activa una barbería dentro de la plataforma.

**Descripción funcional**
- Cada barbería paga su propia mensualidad de forma independiente (si un dueño tiene varias barberías, paga cada una por separado).
- El cobro se gestiona a través de Nequi: el sistema solicita el pago al dueño, quien lo aprueba desde su propia app Nequi.
- De forma complementaria, el administrador cuenta con un registro manual para los casos en que el pago se reciba por otro medio.

**Reglas de negocio**
- Al vencer la mensualidad, la barbería entra en un período de gracia de 3 a 5 días antes de bloquearse por completo.
- Si el dueño cancela la membresía de forma directa (no simplemente deja de pagar), la barbería se bloquea de inmediato, sin pasar por el período de gracia.

### 12.6 Bloqueo por mensualidad vencida
**Objetivo:** Definir el efecto de un bloqueo sobre la barbería, sus barberos y sus clientes.

**Descripción funcional**
- La barbería y todos sus barberos quedan bloqueados para operar dentro de esa barbería.
- La barbería deja de aparecer en cualquier tipo de búsqueda o filtrado del sistema — desaparece del catálogo visible para los clientes.

**Reglas de negocio**
- Las reservas pagadas que ya existían para fechas dentro del período que sí fue pagado no se ven afectadas.
- Las reservas que caían después del corte de mensualidad y quedan atrapadas por el bloqueo se cancelan automáticamente con reembolso al cliente.

---

## 13. Pago

### 13.1 Pasarela de pago
**Objetivo:** Procesar los pagos de reservas, productos y mensualidades de forma segura y ágil.

**Descripción funcional**
- Los pagos se procesan a través de Nequi.
- El usuario aprueba cada pago directamente desde su propia aplicación Nequi, sin necesidad de ingresar datos de tarjeta dentro de la app de la barbería.
- Aplica tanto para pagos de clientes (reservas, productos) como para el pago de la mensualidad por parte de los dueños de barbería.
