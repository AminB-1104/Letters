'use strict';

function success(res, { data = {}, message = 'Operation successful', status = 200 } = {}) {
  return res.status(status).json({ success: true, message, data });
}

function error(res, { message = 'Internal server error', status = 500 } = {}) {
  return res.status(status).json({ success: false, message });
}

module.exports = { success, error };
