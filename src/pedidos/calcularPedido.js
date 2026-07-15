// Lógica de negocio de pedidos de BigRoyal: cálculo de totales, validación
// y descuento de stock según la receta de cada producto.
// El repositorio de insumos se inyecta (en AWS: Prisma → Aurora), lo que
// permite testear las interacciones con mocks.

function calcularTotal(items) {
  const total = items.reduce((acumulado, item) => acumulado + item.precio * item.cantidad, 0);
  return Math.round(total * 100) / 100;
}

function validarPedido(items) {
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error('El pedido debe tener al menos un item');
  }
  for (const item of items) {
    if (!item.cantidad || item.cantidad <= 0) {
      throw new Error('La cantidad debe ser mayor a 0');
    }
  }
  return true;
}

function procesarPedido(items, { recetas, insumosRepo }) {
  validarPedido(items);

  // Primera pasada: verificar TODO el stock antes de descontar nada —
  // si un insumo no alcanza, el pedido se rechaza sin efectos parciales.
  const consumos = [];
  for (const item of items) {
    const receta = recetas[item.producto_id] || [];
    for (const ingrediente of receta) {
      const requerido = ingrediente.cantidad * item.cantidad;
      const disponible = insumosRepo.obtenerStock(ingrediente.insumo_id);
      if (disponible < requerido) {
        throw new Error(`Stock insuficiente de ${ingrediente.insumo_id}`);
      }
      consumos.push({ insumo_id: ingrediente.insumo_id, cantidad: requerido });
    }
  }

  // Segunda pasada: descontar
  for (const consumo of consumos) {
    insumosRepo.descontarStock(consumo.insumo_id, consumo.cantidad);
  }

  return { total: calcularTotal(items), items: items.length };
}

module.exports = { calcularTotal, validarPedido, procesarPedido };
