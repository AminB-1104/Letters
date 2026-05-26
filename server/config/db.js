'use strict';

const mongoose = require('mongoose');
const env = require('./env');

const RETRY_DELAY_MS = 5000;

async function connect() {
  if (!env.mongoUri) {
    // eslint-disable-next-line no-console
    console.warn('[db] MONGO_URI is not set; skipping connection attempt.');
    return;
  }

  try {
    await mongoose.connect(env.mongoUri);
    // eslint-disable-next-line no-console
    console.log('[db] MongoDB connected');
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(
      `[db] MongoDB connection failed: ${err.message}. Retrying in ${RETRY_DELAY_MS}ms...`
    );
    setTimeout(connect, RETRY_DELAY_MS);
  }
}

mongoose.connection.on('disconnected', () => {
  // eslint-disable-next-line no-console
  console.warn('[db] MongoDB disconnected — reconnecting...');
  connect();
});

module.exports = { connect };
