'use strict';

const express = require('express');
const cors = require('cors');

const env = require('./config/env');
const db = require('./config/db');
const routes = require('./routes');
const { errorHandler, notFoundHandler } = require('./middleware/error-handler');

const app = express();

app.use(cors());
app.use(express.json());

app.use('/', routes);

app.use(notFoundHandler);
app.use(errorHandler);

db.connect();

app.listen(env.port, () => {
  // eslint-disable-next-line no-console
  console.log(`[server] Letters API listening on http://localhost:${env.port}`);
});

module.exports = app;
