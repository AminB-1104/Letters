'use strict';

const express = require('express');
const chatController = require('../controllers/chat-controller');
const authMiddleware = require('../middleware/auth-middleware');

const router = express.Router();

router.use(authMiddleware);

router.post('/create', chatController.create);
router.get('/list', chatController.list);
router.get('/:chatId', chatController.detail);

module.exports = router;
