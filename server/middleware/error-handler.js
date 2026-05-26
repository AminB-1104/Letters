'use strict';

const { error } = require('../utils/api-response');

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const status = err.status || err.statusCode || 500;
  // eslint-disable-next-line no-console
  console.error(`[error] ${req.method} ${req.originalUrl} -> ${status}: ${err.message}`);
  return error(res, {
    status,
    message: err.expose ? err.message : status >= 500 ? 'Internal server error' : err.message,
  });
}

function notFoundHandler(req, res) {
  return error(res, { status: 404, message: `Route not found: ${req.method} ${req.originalUrl}` });
}

module.exports = { errorHandler, notFoundHandler };
