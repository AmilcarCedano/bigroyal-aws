// Suite 1 — Gestión de usuarios (casos 1-5 del plan, ver docs/PLAN-TESTS.md)
// La capa de datos (usersRepository) se reemplaza con jest.mock: los tests
// verifican la lógica de negocio Y las interacciones con el repositorio.
jest.mock('./usersRepository');

const repo = require('./usersRepository');
const { crearUsuario, listarUsuarios } = require('./usersController');

describe('usersController', () => {
  beforeEach(() => jest.resetAllMocks());

  test('caso 1: crea un usuario válido y lo guarda en el repositorio', () => {
    // Arrange
    const datos = { nombre: 'Carlos Cajero', email: 'carlos@bigroyal.com', rol: 'cajero', password_hash: 'hash' };
    repo.buscarPorEmail.mockReturnValue(null);
    repo.guardar.mockReturnValue({ id: '1', ...datos });

    // Act
    const creado = crearUsuario(datos);

    // Assert
    expect(creado.id).toBe('1');
    expect(creado.email).toBe('carlos@bigroyal.com');
    expect(repo.guardar).toHaveBeenCalledWith(datos);
  });

  test('caso 2: rechaza email duplicado y NO llama a guardar', () => {
    // Arrange
    repo.buscarPorEmail.mockReturnValue({ id: '9', email: 'carlos@bigroyal.com' });

    // Act + Assert
    expect(() =>
      crearUsuario({ nombre: 'Otro', email: 'carlos@bigroyal.com', rol: 'cajero' })
    ).toThrow('El email ya está registrado');
    expect(repo.guardar).not.toHaveBeenCalled();
  });

  test('caso 3: rechaza email con formato inválido', () => {
    // Arrange
    const datos = { nombre: 'Ana', email: 'no-es-un-email', rol: 'admin' };

    // Act + Assert
    expect(() => crearUsuario(datos)).toThrow('El email no tiene un formato válido');
  });

  test('caso 4: rechaza un rol que no existe en el sistema', () => {
    // Arrange
    const datos = { nombre: 'Ana', email: 'ana@bigroyal.com', rol: 'gerente' };

    // Act + Assert
    expect(() => crearUsuario(datos)).toThrow('Rol inválido');
  });

  test('caso 5: listar usuarios nunca expone el password_hash', () => {
    // Arrange
    repo.listar.mockReturnValue([
      { id: '1', nombre: 'Admin', email: 'a@b.com', rol: 'admin', password_hash: 'secreto1' },
      { id: '2', nombre: 'Cajero', email: 'c@b.com', rol: 'cajero', password_hash: 'secreto2' },
    ]);

    // Act
    const lista = listarUsuarios();

    // Assert
    expect(lista).toHaveLength(2);
    for (const u of lista) {
      expect(u.password_hash).toBeUndefined();
    }
  });
});
