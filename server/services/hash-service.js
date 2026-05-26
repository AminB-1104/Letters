'use strict';

const bcrypt = require('bcrypt');

const SALT_ROUNDS = 12;

function hash(plain) {
  return bcrypt.hash(plain, SALT_ROUNDS);
}

function compare(plain, hashed) {
  return bcrypt.compare(plain, hashed);
}

module.exports = { hash, compare };
