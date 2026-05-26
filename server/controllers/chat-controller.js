'use strict';

const asyncHandler = require('../utils/async-handler');
const { success } = require('../utils/api-response');
const chatService = require('../services/chat-service');

const create = asyncHandler(async (req, res) => {
  const { userId } = req.body || {};
  const { chat, created } = await chatService.createOrGetChat({
    userId: req.user.id,
    otherUserId: userId,
  });

  return success(res, {
    status: created ? 201 : 200,
    message: created ? 'Chat created' : 'Chat already exists',
    data: { chat },
  });
});

const list = asyncHandler(async (req, res) => {
  const { page, limit } = req.query;
  const result = await chatService.listChats({
    userId: req.user.id,
    page,
    limit,
  });

  return success(res, {
    status: 200,
    message: 'Chat list',
    data: result,
  });
});

const detail = asyncHandler(async (req, res) => {
  const chat = await chatService.getChatById({
    userId: req.user.id,
    chatId: req.params.chatId,
  });

  return success(res, {
    status: 200,
    message: 'Chat detail',
    data: { chat },
  });
});

module.exports = { create, list, detail };
