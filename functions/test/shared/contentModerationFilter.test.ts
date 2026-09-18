import { containsOffensiveContent } from '../../src/shared/contentModerationFilter';

describe('containsOffensiveContent', () => {
  it('deja pasar comentarios normales', () => {
    expect(containsOffensiveContent('Excelente corte, muy puntual y amable.')).toBe(false);
  });

  it('deja pasar texto vacío o en blanco', () => {
    expect(containsOffensiveContent('')).toBe(false);
    expect(containsOffensiveContent('   ')).toBe(false);
  });

  it('detecta una grosería directa', () => {
    expect(containsOffensiveContent('El barbero es un idiota')).toBe(true);
  });

  it('detecta groserías con acentos y mayúsculas', () => {
    expect(containsOffensiveContent('Qué ESTÚPIDO servicio')).toBe(true);
  });

  it('detecta evasión con leetspeak', () => {
    expect(containsOffensiveContent('p3nd3jo el barbero')).toBe(true);
  });

  it('detecta evasión con letras sueltas separadas por espacios', () => {
    expect(containsOffensiveContent('el barbero es un p u t o')).toBe(true);
  });

  it('detecta evasión con letras repetidas', () => {
    expect(containsOffensiveContent('puuutooo servicio')).toBe(true);
  });

  it('no marca falsos positivos en palabras que contienen una prohibida por casualidad', () => {
    expect(containsOffensiveContent('Quedé con buen vínculo con mi barbero')).toBe(false);
    expect(containsOffensiveContent('Hice el cálculo del precio y está bien')).toBe(false);
  });
});
