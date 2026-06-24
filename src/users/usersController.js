const users = [
  { id: 1, name: 'Anderson Cedano', role: 'admin' },
  { id: 2, name: 'Leonardo Chavez', role: 'developer' },
  { id: 3, name: 'Sergio Coronado', role: 'developer' },
];

function getUsers() {
  return users;
}

function getUserById(id) {
  return users.find((u) => u.id === id) || null;
}

function createUser(user) {
  if (!user.name || !user.role) {
    throw new Error('El usuario debe tener nombre y rol');
  }
  const newUser = { id: users.length + 1, ...user };
  users.push(newUser);
  return newUser;
}

function deleteUser(id) {
  const index = users.findIndex((u) => u.id === id);
  if (index === -1) return false;
  users.splice(index, 1);
  return true;
}

module.exports = { getUsers, getUserById, createUser, deleteUser };
