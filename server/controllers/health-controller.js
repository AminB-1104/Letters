'use strict';

const mongoose = require('mongoose');
const { success } = require('../utils/api-response');

function getHealth(req, res) {
  return success(res, {
    message: 'Service healthy',
    data: {
      uptime: process.uptime(),
      mongo:
        mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
      timestamp: new Date().toISOString(),
    },
  });
}

module.exports = { getHealth };
