'use strict';

const User = require('../models/user-model');
const hashService = require('./hash-service');
const jwtService = require('./jwt-service');

function toPublicUser(doc) {
  return {
    id: doc._id.toString(),
    username: doc.username,
    displayName: doc.displayName,
    createdAt: doc.createdAt,
  };
}

function makeError(status, message) {
  const err = new Error(message);
  err.status = status;
  err.expose = true;
  return err;
}

async function registerUser({ username, displayName, password }) {
  const normalizedUsername = username.toLowerCase();

  const existing = await User.findOne({ username: normalizedUsername });
  if (existing) {
    throw makeError(409, 'Username already taken');
  }

  const passwordHash = await hashService.hash(password);
  const doc = await User.create({
    username: normalizedUsername,
    displayName,
    passwordHash,
  });

  const user = toPublicUser(doc);
  const token = jwtService.sign({ id: user.id, username: user.username });
  return { user, token };
}

async function loginUser({ username, password }) {
  const doc = await User.findOne({ username: username.toLowerCase() });
  if (!doc) {
    throw makeError(401, 'Invalid credentials');
  }

  const ok = await hashService.compare(password, doc.passwordHash);
  if (!ok) {
    throw makeError(401, 'Invalid credentials');
  }

  const user = toPublicUser(doc);
  const token = jwtService.sign({ id: user.id, username: user.username });
  return { user, token };
}

async function getCurrentUser(userId) {
  const doc = await User.findById(userId);
  if (!doc) {
    throw makeError(404, 'User not found');
  }
  return toPublicUser(doc);
}

module.exports = { registerUser, loginUser, getCurrentUser };
