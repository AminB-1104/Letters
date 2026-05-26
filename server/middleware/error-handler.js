'use strict';

const { error } = require('../utils/api-response');

function normalize(err) {
  if (err && err.name === 'ValidationError' && err.errors) {
    const first = Object.values(err.errors)[0];
    return {
      status: 400,
      message: first && first.message ? first.message : 'Validation failed',
    };
  }
  if (err && err.code === 11000) {
    return { status: 409, message: 'Username already taken' };
  }
  if (err && (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError')) {
    return { status: 401, message: 'Invalid or expired token' };
  }
  if (err && err.name === 'CastError') {
    return { status: 400, message: 'Invalid identifier' };
  }
  return null;
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const mapped = normalize(err);
  const status = mapped ? mapped.status : err.status || err.statusCode || 500;
  const message = mapped
    ? mapped.message
    : err.expose
      ? err.message
      : status >= 500
        ? 'Internal server error'
        : err.message;

  // eslint-disable-next-line no-console
  console.error(`[error] ${req.method} ${req.originalUrl} -> ${status}: ${err.message}`);
  return error(res, { status, message });
}

function notFoundHandler(req, res) {
  return error(res, { status: 404, message: `Route not found: ${req.method} ${req.originalUrl}` });
}

module.exports = { errorHandler, notFoundHandler };
