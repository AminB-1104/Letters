'use strict';

const express = require('express');
const friendController = require('../controllers/friend-controller');
const authMiddleware = require('../middleware/auth-middleware');

const router = express.Router();

router.use(authMiddleware);

router.post('/send-request', friendController.sendRequest);
router.post('/accept-request', friendController.acceptRequest);
router.post('/decline-request', friendController.declineRequest);
router.post('/remove-friend', friendController.removeFriend);
router.get('/list', friendController.listFriends);
router.get('/requests', friendController.listRequests);

module.exports = router;
