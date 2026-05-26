'use strict';

require('dotenv').config();

const required = ['PORT', 'MONGO_URI', 'JWT_SECRET'];
const missing = required.filter((key) => !process.env[key]);

if (missing.length > 0) {
  // eslint-disable-next-line no-console
  console.warn(
    `[env] Missing required env vars: ${missing.join(', ')}. ` +
      'Copy server/.env.example to server/.env to set them.'
  );
}

module.exports = {
  port: Number(process.env.PORT) || 3000,
  mongoUri: process.env.MONGO_URI || '',
  jwtSecret: process.env.JWT_SECRET || '',
  nodeEnv: process.env.NODE_ENV || 'development',
};
