// Suite 3 — Lógica de pedidos (casos 11-15 del plan, ver docs/PLAN-TESTS.md)
// El repositorio de insumos se simula con jest.fn(): los casos 14 y 15
// verifican las INTERACCIONES (qué se descontó y qué no) además del resultado.
const { calcularTotal, validarPedido, procesarPedido } = require('./calcularPedido');

describe('pedidos', () => {
  test('caso 11: calcula el total con varios items (cantidad x precio)', () => {
    // Arrange
    const items = [
      { producto_id: 'prod-001', nombre: '1/4 Pollo', precio: 15.9, cantidad: 2 },
      { producto_id: 'prod-005', nombre: 'Gaseosa', precio: 5.0, cantidad: 1 },
    ];

    // Act
    const total = calcularTotal(items);

    // Assert
    expect(total).toBe(36.8);
  });

  test('caso 12: rechaza un pedido sin items', () => {
    // Arrange
    const items = [];

    // Act + Assert
    expect(() => validarPedido(items)).toThrow('El pedido debe tener al menos un item');
  });

  test('caso 13: rechaza un item con cantidad menor o igual a cero', () => {
    // Arrange
    const items = [{ producto_id: 'prod-001', precio: 15.9, cantidad: 0 }];

    // Act + Assert
    expect(() => validarPedido(items)).toThrow('La cantidad debe ser mayor a 0');
  });

  test('caso 14: descuenta el stock según la receta del producto', () => {
    // Arrange — receta: 1/4 pollo consume 0.25 de pollo y 0.15 de papa
    const recetas = {
      'prod-001': [
        { insumo_id: 'ins-pollo', cantidad: 0.25 },
        { insumo_id: 'ins-papa', cantidad: 0.15 },
      ],
    };
    const insumosRepo = {
      obtenerStock: jest.fn().mockReturnValue(50),
      descontarStock: jest.fn(),
    };
    const items = [{ producto_id: 'prod-001', precio: 15.9, cantidad: 1 }];

    // Act
    const resultado = procesarPedido(items, { recetas, insumosRepo });

    // Assert
    expect(resultado.total).toBe(15.9);
    expect(insumosRepo.descontarStock).toHaveBeenCalledWith('ins-pollo', 0.25);
    expect(insumosRepo.descontarStock).toHaveBeenCalledWith('ins-papa', 0.15);
  });

  test('caso 15: con stock insuficiente rechaza y NO descuenta nada', () => {
    // Arrange — solo queda 0.1 de pollo y el pedido necesita 0.25
    const recetas = {
      'prod-001': [{ insumo_id: 'ins-pollo', cantidad: 0.25 }],
    };
    const insumosRepo = {
      obtenerStock: jest.fn().mockReturnValue(0.1),
      descontarStock: jest.fn(),
    };
    const items = [{ producto_id: 'prod-001', precio: 15.9, cantidad: 1 }];

    // Act + Assert
    expect(() => procesarPedido(items, { recetas, insumosRepo })).toThrow('Stock insuficiente');
    expect(insumosRepo.descontarStock).not.toHaveBeenCalled();
  });
});
