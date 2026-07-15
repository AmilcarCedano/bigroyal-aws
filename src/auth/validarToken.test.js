// Suite 2 — Autenticación (casos 6-10 del plan, ver docs/PLAN-TESTS.md)
// Refleja la lógica del middleware real del backend: en AWS el API Gateway ya
// verificó la firma del token de Cognito, así que la unidad valida estructura,
// expiración y mapeo de claims.
const { validarToken } = require('./validarToken');

// Helper: construye un ID token de Cognito de prueba (header.payload.firma)
function tokenCognito(claims = {}, opciones = {}) {
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({
      iss: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_demo',
      exp: opciones.exp ?? Math.floor(Date.now() / 1000) + 3600,
      ...claims,
    })
  ).toString('base64url');
  return `${header}.${payload}.firma-de-prueba`;
}

describe('validarToken', () => {
  test('caso 6: sin header Authorization responde 401 Token requerido', () => {
    // Arrange
    const header = undefined;

    // Act
    const resultado = validarToken(header);

    // Assert
    expect(resultado.ok).toBe(false);
    expect(resultado.status).toBe(401);
    expect(resultado.error).toBe('Token requerido');
  });

  test('caso 7: token malformado responde 401 Token inválido', () => {
    // Arrange
    const header = 'Bearer esto-no-es-un-jwt';

    // Act
    const resultado = validarToken(header);

    // Assert
    expect(resultado.ok).toBe(false);
    expect(resultado.error).toBe('Token inválido');
  });

  test('caso 8: token Cognito válido mapea los claims al usuario', () => {
    // Arrange
    const header = `Bearer ${tokenCognito({
      'custom:db_id': 'aaaaaaaa-0000-0000-0000-000000000001',
      'custom:rol': 'admin',
      'custom:sede_id': '11111111-1111-1111-1111-111111111111',
    })}`;

    // Act
    const resultado = validarToken(header);

    // Assert
    expect(resultado.ok).toBe(true);
    expect(resultado.usuario).toEqual({
      id: 'aaaaaaaa-0000-0000-0000-000000000001',
      rol: 'admin',
      sede_id: '11111111-1111-1111-1111-111111111111',
    });
  });

  test('caso 9: token Cognito sin atributos custom responde 401', () => {
    // Arrange — token válido pero sin custom:rol ni custom:db_id
    const header = `Bearer ${tokenCognito({ email: 'alguien@bigroyal.com' })}`;

    // Act
    const resultado = validarToken(header);

    // Assert
    expect(resultado.ok).toBe(false);
    expect(resultado.error).toBe('Token sin atributos de usuario');
  });

  test('caso 10: token expirado responde 401 Token expirado', () => {
    // Arrange — exp una hora en el pasado
    const header = `Bearer ${tokenCognito(
      { 'custom:db_id': 'x', 'custom:rol': 'admin' },
      { exp: Math.floor(Date.now() / 1000) - 3600 }
    )}`;

    // Act
    const resultado = validarToken(header);

    // Assert
    expect(resultado.ok).toBe(false);
    expect(resultado.error).toBe('Token expirado');
  });
});
