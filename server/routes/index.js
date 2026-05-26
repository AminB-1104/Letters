'use strict';

const express = require('express');
const healthRoutes = require('./health-routes');
const authRoutes = require('./auth-routes');
const userRoutes = require('./user-routes');
const friendRoutes = require('./friend-routes');

const router = express.Router();

router.use('/health', healthRoutes);

const apiRouter = express.Router();
apiRouter.use('/auth', authRoutes);
apiRouter.use('/users', userRoutes);
apiRouter.use('/friends', friendRoutes);
router.use('/api', apiRouter);

module.exports = router;
