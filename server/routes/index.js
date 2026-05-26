'use strict';

const express = require('express');
const healthRoutes = require('./health-routes');
const authRoutes = require('./auth-routes');
const userRoutes = require('./user-routes');
const friendRoutes = require('./friend-routes');
const chatRoutes = require('./chat-routes');
const messageRoutes = require('./message-routes');

const router = express.Router();

router.use('/health', healthRoutes);

const apiRouter = express.Router();
apiRouter.use('/auth', authRoutes);
apiRouter.use('/users', userRoutes);
apiRouter.use('/friends', friendRoutes);
apiRouter.use('/chats', chatRoutes);
apiRouter.use('/messages', messageRoutes);
router.use('/api', apiRouter);

module.exports = router;
