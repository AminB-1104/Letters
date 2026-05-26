'use strict';

const jwt = require('jsonwebtoken');
const env = require('../config/env');

function sign(payload, { expiresIn = env.jwtExpiresIn } = {}) {
  return jwt.sign(payload, env.jwtSecret, { expiresIn });
}

function verify(token) {
  return jwt.verify(token, env.jwtSecret);
}

module.exports = { sign, verify };
