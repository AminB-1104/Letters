'use strict';

const jwt = require('jsonwebtoken');
const env = require('../config/env');

const DEFAULT_EXPIRES_IN = '7d';

function sign(payload, { expiresIn = DEFAULT_EXPIRES_IN } = {}) {
  return jwt.sign(payload, env.jwtSecret, { expiresIn });
}

function verify(token) {
  return jwt.verify(token, env.jwtSecret);
}

module.exports = { sign, verify };
