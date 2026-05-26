'use strict';

const jwtService = require('../services/jwt-service');
const { error } = require('../utils/api-response');

// Defined but NOT mounted in Phase 01 (spec §7).
// Phase 02 will wire this onto protected routes.
function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return error(res, { status: 401, message: 'Authentication token missing' });
  }

  try {
    const payload = jwtService.verify(token);
    req.user = payload;
    return next();
  } catch (e) {
    return error(res, { status: 401, message: 'Invalid or expired token' });
  }
}

module.exports = authMiddleware;
