'use strict';

const express = require('express');
const healthRoutes = require('./health-routes');
const authRoutes = require('./auth-routes');

const router = express.Router();

router.use('/health', healthRoutes);

const apiRouter = express.Router();
apiRouter.use('/auth', authRoutes);
router.use('/api', apiRouter);

module.exports = router;
