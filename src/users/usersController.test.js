const { getUsers, getUserById, createUser, deleteUser } = require('./usersController');

describe('usersController', () => {

  test('retorna todos los usuarios', () => {
    const result = getUsers();
    expect(Array.isArray(result)).toBe(true);
    expect(result.length).toBeGreaterThan(0);
  });

  test('retorna un usuario por id existente', () => {
    const user = getUserById(1);
    expect(user).not.toBeNull();
    expect(user.id).toBe(1);
    expect(user.name).toBe('Anderson Cedano');
  });

  test('retorna null para un id inexistente', () => {
    const user = getUserById(999);
    expect(user).toBeNull();
  });

  test('crea un nuevo usuario correctamente', () => {
    const newUser = createUser({ name: 'Carlos Lopez', role: 'viewer' });
    expect(newUser.id).toBeDefined();
    expect(newUser.name).toBe('Carlos Lopez');
    expect(newUser.role).toBe('viewer');
  });

  test('lanza error si falta nombre o rol al crear usuario', () => {
    expect(() => createUser({ name: 'Solo nombre' })).toThrow('El usuario debe tener nombre y rol');
    expect(() => createUser({ role: 'admin' })).toThrow('El usuario debe tener nombre y rol');
  });

  test('elimina un usuario existente', () => {
    const result = deleteUser(1);
    expect(result).toBe(true);
  });

  test('retorna false al eliminar un usuario inexistente', () => {
    const result = deleteUser(999);
    expect(result).toBe(false);
  });

});
