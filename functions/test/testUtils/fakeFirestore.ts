/**
 * Firestore en memoria mínimo para probar lógica de negocio sin el
 * emulador: soporta get/add/set/update, where() encadenado (solo '==' y
 * '<=', lo único que usa este backend) y batch(). No pretende ser un mock
 * completo del SDK — solo lo que los servicios de functions/src usan hoy.
 */

type DocData = Record<string, unknown>;

interface DocHandle {
  id: string;
  path: string;
  get(): Promise<{ exists: boolean; data: () => DocData | undefined; ref: DocHandle; id: string }>;
  set(data: DocData): Promise<void>;
  update(patch: DocData): Promise<void>;
  delete(): Promise<void>;
  collection(name: string): CollectionHandle;
}

interface TransactionHandle {
  get(ref: DocHandle): Promise<{ exists: boolean; data: () => DocData | undefined; ref: DocHandle; id: string }>;
  set(ref: DocHandle, data: DocData): void;
  update(ref: DocHandle, patch: DocData): void;
  delete(ref: DocHandle): void;
}

interface CollectionHandle {
  doc(id?: string): DocHandle;
  add(data: DocData): Promise<DocHandle>;
  where(field: string, op: string, value: unknown): QueryHandle;
}

interface QueryHandle {
  where(field: string, op: string, value: unknown): QueryHandle;
  get(): Promise<{ empty: boolean; size: number; docs: Array<{ ref: DocHandle; data: () => DocData; id: string }> }>;
}

const ARRAY_UNION = Symbol('fakeFirestore.arrayUnion');

interface ArrayUnionSentinel {
  [ARRAY_UNION]: true;
  values: unknown[];
}

function isArrayUnion(value: unknown): value is ArrayUnionSentinel {
  return typeof value === 'object' && value !== null && ARRAY_UNION in value;
}

/** Compañero de createFakeFirestore(): mockea FieldValue en el mismo jest.mock. */
export function createFakeFieldValue() {
  return {
    serverTimestamp: () => 'SERVER_TIMESTAMP',
    arrayUnion: (...values: unknown[]): ArrayUnionSentinel => ({ [ARRAY_UNION]: true, values }),
  };
}

function resolvePatch(existing: DocData, patch: DocData): DocData {
  const resolved: DocData = { ...existing };
  for (const [key, value] of Object.entries(patch)) {
    if (isArrayUnion(value)) {
      const current = Array.isArray(existing[key]) ? (existing[key] as unknown[]) : [];
      resolved[key] = [...current, ...value.values];
    } else {
      resolved[key] = value;
    }
  }
  return resolved;
}

function matches(actual: unknown, op: string, expected: unknown): boolean {
  // Como en Firestore real: un campo ausente o null nunca cumple una
  // desigualdad (si no, JS coerciona null -> 0 y lo trataría como "muy en
  // el pasado", dando falsos positivos p.ej. en barberos que no están afuera).
  if (op !== '==' && (actual === null || actual === undefined)) return false;

  switch (op) {
    case '==':
      return actual === expected;
    case '<=':
      return (actual as number | Date) <= (expected as number | Date);
    case '>=':
      return (actual as number | Date) >= (expected as number | Date);
    case '>':
      return (actual as number | Date) > (expected as number | Date);
    default:
      throw new Error(`Operador no soportado en el fake: ${op}`);
  }
}

export function createFakeFirestore() {
  const store = new Map<string, DocData>();
  let autoCounter = 0;

  function docHandle(path: string): DocHandle {
    return {
      id: path.split('/').pop()!,
      path,
      get: async () => ({
        exists: store.has(path),
        data: () => store.get(path),
        ref: docHandle(path),
        id: path.split('/').pop()!,
      }),
      set: async (data: DocData) => {
        store.set(path, data);
      },
      update: async (patch: DocData) => {
        if (!store.has(path)) throw new Error(`No document to update: ${path}`);
        store.set(path, resolvePatch(store.get(path)!, patch));
      },
      delete: async () => {
        store.delete(path);
      },
      collection: (name: string) => collectionHandle(`${path}/${name}`),
    };
  }

  function collectionHandle(basePath: string): CollectionHandle {
    function query(filters: Array<[string, string, unknown]>): QueryHandle {
      return {
        where: (field: string, op: string, value: unknown) => query([...filters, [field, op, value]]),
        get: async () => {
          const docs = [...store.entries()]
            .filter(([path]) => path.startsWith(`${basePath}/`) && !path.slice(basePath.length + 1).includes('/'))
            .filter(([, data]) => filters.every(([field, op, value]) => matches(data[field], op, value)))
            .map(([path, data]) => ({ ref: docHandle(path), data: () => data, id: path.split('/').pop()! }));
          return { empty: docs.length === 0, size: docs.length, docs };
        },
      };
    }

    return {
      doc: (id?: string) => docHandle(`${basePath}/${id ?? `auto${autoCounter++}`}`),
      add: async (data: DocData) => {
        const ref = docHandle(`${basePath}/auto${autoCounter++}`);
        await ref.set(data);
        return ref;
      },
      where: (field: string, op: string, value: unknown) => query([[field, op, value]]),
    };
  }

  return {
    collection: (name: string) => collectionHandle(name),
    doc: (path: string) => docHandle(path),
    /**
     * No simula aislamiento real entre transacciones concurrentes (los
     * tests corren secuencialmente) — sí reproduce la propiedad que
     * importa: si el callback lanza antes de terminar, ninguna de sus
     * escrituras queda aplicada.
     */
    runTransaction: async <T>(fn: (tx: TransactionHandle) => Promise<T>): Promise<T> => {
      const pendingWrites: Array<() => Promise<void>> = [];
      const tx: TransactionHandle = {
        get: (ref: DocHandle) => ref.get(),
        set: (ref: DocHandle, data: DocData) => {
          pendingWrites.push(() => ref.set(data));
        },
        update: (ref: DocHandle, patch: DocData) => {
          pendingWrites.push(() => ref.update(patch));
        },
        delete: (ref: DocHandle) => {
          pendingWrites.push(() => ref.delete());
        },
      };

      const result = await fn(tx);
      for (const write of pendingWrites) await write();
      return result;
    },
    batch: () => {
      const pending: Array<() => Promise<void>> = [];
      return {
        update: (ref: DocHandle, patch: DocData) => {
          pending.push(() => ref.update(patch));
        },
        commit: async () => {
          for (const op of pending) await op();
        },
      };
    },
    /** Solo para tests: siembra un documento saltándose el resto de la API. */
    seed: (path: string, data: DocData) => store.set(path, data),
    /** Solo para tests: limpia todo entre casos para que no se contaminen entre sí. */
    reset: () => {
      store.clear();
      autoCounter = 0;
    },
  };
}

export type FakeFirestore = ReturnType<typeof createFakeFirestore>;
