// Validación de tokens de Cognito — refleja la lógica del middleware real
// del backend (backend/src/middlewares/auth.js).
//
// En AWS el JWT authorizer del API Gateway ya verificó la FIRMA del token
// antes de invocar la Lambda; esta unidad valida estructura, expiración y
// mapea los claims custom (db_id, rol, sede_id) al usuario de la aplicación.

function decodificarPayload(token) {
  const partes = token.split('.');
  if (partes.length !== 3) return null;
  try {
    const base64 = partes[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(Buffer.from(base64, 'base64').toString('utf8'));
  } catch {
    return null;
  }
}

function validarToken(headerAuthorization) {
  const token = headerAuthorization?.split(' ')[1];
  if (!token) {
    return { ok: false, status: 401, error: 'Token requerido' };
  }

  const payload = decodificarPayload(token);
  if (!payload) {
    return { ok: false, status: 401, error: 'Token inválido' };
  }

  const esCognito = typeof payload.iss === 'string' && payload.iss.includes('cognito-idp');
  if (!esCognito) {
    return { ok: false, status: 401, error: 'Token inválido' };
  }

  if (payload.exp && payload.exp * 1000 < Date.now()) {
    return { ok: false, status: 401, error: 'Token expirado' };
  }

  const usuario = {
    id: payload['custom:db_id'],
    rol: payload['custom:rol'],
    sede_id: payload['custom:sede_id'],
  };
  if (!usuario.id || !usuario.rol) {
    return { ok: false, status: 401, error: 'Token sin atributos de usuario' };
  }

  return { ok: true, usuario };
}

module.exports = { validarToken };
