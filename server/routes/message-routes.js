'use strict';

const express = require('express');
const messageController = require('../controllers/message-controller');
const authMiddleware = require('../middleware/auth-middleware');

const router = express.Router();

router.use(authMiddleware);

router.post('/send', messageController.send);
router.get('/:chatId', messageController.list);

module.exports = router;
