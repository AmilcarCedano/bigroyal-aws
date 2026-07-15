# Plan de Tests Unitarios — BigRoyal

> Documento de planificación previo a la escritura de los tests (metodología TDD:
> primero se piensan y documentan todos los casos, luego se escriben los tests,
> y recién al final el código que los hace pasar).

## Metodología

- **Patrón AAA** (Arrange–Act–Assert) en cada caso.
- **Mocks con librería**: `jest.mock()` de Jest para simular la capa de datos
  (repositorios). Los mocks permiten verificar *interacciones* — qué se llamó,
  con qué argumentos, y qué NO se llamó.
- **Ejecución**: los tests corren en dos momentos:
  1. **Git hook `pre-push`** (Husky) — localmente, antes de que el código salga de la máquina.
  2. **GitHub Actions** (job `Unit Tests` en `ci-dev.yml`) — en cada Pull Request,
     como check obligatorio antes del merge.

## Los 15 casos planificados

### Suite 1 — Gestión de usuarios (`src/users`) — mocks del repositorio

| # | Caso | Arrange | Act | Assert |
|---|------|---------|-----|--------|
| 1 | Crear usuario válido | Mock repo: email no existe | `crearUsuario(datos válidos)` | Devuelve usuario con id; `repo.guardar` fue llamado con los datos |
| 2 | Email duplicado | Mock repo: `buscarPorEmail` devuelve un usuario | `crearUsuario` con ese email | Lanza "email ya registrado"; `repo.guardar` NO fue llamado |
| 3 | Email inválido | Datos con email sin formato válido | `crearUsuario` | Lanza error de validación de email |
| 4 | Rol inexistente | Datos con rol "gerente" | `crearUsuario` | Lanza error: rol debe ser admin/cajero/planchero |
| 5 | Listar sin exponer contraseñas | Mock repo con 2 usuarios con `password_hash` | `listarUsuarios()` | Ningún elemento contiene `password_hash` |

### Suite 2 — Autenticación (`src/auth`) — lógica del middleware real

| # | Caso | Arrange | Act | Assert |
|---|------|---------|-----|--------|
| 6 | Sin token | Header Authorization ausente | `validarToken(undefined)` | `{ ok: false, status: 401, error: "Token requerido" }` |
| 7 | Token malformado | Header "Bearer basura-no-jwt" | `validarToken` | 401 "Token inválido" |
| 8 | Token Cognito válido | JWT con iss cognito-idp y claims custom:db_id/rol/sede_id | `validarToken` | `usuario` mapeado: id, rol y sede_id correctos |
| 9 | Token Cognito sin atributos | JWT de Cognito sin `custom:rol` | `validarToken` | 401 "sin atributos de usuario" |
| 10 | Token expirado | JWT de Cognito con `exp` en el pasado | `validarToken` | 401 "expirado" |

### Suite 3 — Lógica de pedidos (`src/pedidos`) — mocks del repositorio de insumos

| # | Caso | Arrange | Act | Assert |
|---|------|---------|-----|--------|
| 11 | Total con varios items | Carrito: 2 × 1/4 pollo (S/15.90) + 1 × gaseosa (S/5.00) | `calcularTotal` | Total = S/36.80 |
| 12 | Pedido vacío | Carrito sin items | `validarPedido` | Rechazado: "el pedido debe tener al menos un item" |
| 13 | Cantidad inválida | Item con cantidad 0 | `validarPedido` | Rechazado: "cantidad debe ser mayor a 0" |
| 14 | Descuento de stock por receta | Mock insumos con stock; receta 1/4 pollo = 0.25 pollo + 0.15 papa | `procesarPedido` | `descontarStock` llamado con 0.25 y 0.15 exactos |
| 15 | Stock insuficiente | Mock con stock de pollo = 0.1 | `procesarPedido` de 1/4 pollo | Rechaza "stock insuficiente"; `descontarStock` NO fue llamado |

## Criterio de aceptación

- Los 15 tests pasan localmente (`npm test`) y en el workflow del PR.
- Cobertura reportada a SonarCloud vía `coverage/lcov.info`.
- Ningún PR puede mergearse con tests en rojo.
