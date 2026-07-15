// Capa de acceso a datos de usuarios.
// En AWS esta capa es Prisma → Aurora PostgreSQL; aquí es una implementación
// en memoria con la misma interfaz. Los tests la reemplazan con jest.mock.
const usuarios = [];

function buscarPorEmail(email) {
  return usuarios.find((u) => u.email === email) || null;
}

function guardar(usuario) {
  const nuevo = { id: String(usuarios.length + 1), ...usuario };
  usuarios.push(nuevo);
  return nuevo;
}

function listar() {
  return usuarios;
}

module.exports = { buscarPorEmail, guardar, listar };
