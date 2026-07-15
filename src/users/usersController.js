// Lógica de negocio de gestión de usuarios de BigRoyal.
// Valida datos de entrada y delega la persistencia en usersRepository
// (en AWS: Prisma → Aurora). Nunca expone el password_hash hacia afuera.
const repo = require('./usersRepository');

const ROLES_VALIDOS = ['admin', 'cajero', 'planchero'];
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function crearUsuario(datos) {
  const { nombre, email, rol } = datos;

  if (!nombre || !email || !rol) {
    throw new Error('El usuario debe tener nombre, email y rol');
  }
  if (!EMAIL_REGEX.test(email)) {
    throw new Error('El email no tiene un formato válido');
  }
  if (!ROLES_VALIDOS.includes(rol)) {
    throw new Error(`Rol inválido: debe ser uno de ${ROLES_VALIDOS.join(', ')}`);
  }
  if (repo.buscarPorEmail(email)) {
    throw new Error('El email ya está registrado');
  }

  const creado = repo.guardar(datos);
  const { password_hash: _omitido, ...sinPassword } = creado;
  return sinPassword;
}

function listarUsuarios() {
  return repo.listar().map(({ password_hash: _omitido, ...usuario }) => usuario);
}

module.exports = { crearUsuario, listarUsuarios };
