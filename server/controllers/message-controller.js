'use strict';

const asyncHandler = require('../utils/async-handler');
const { success } = require('../utils/api-response');
const messageService = require('../services/message-service');

const send = asyncHandler(async (req, res) => {
  const { chatId, content } = req.body || {};
  const message = await messageService.sendMessage({
    userId: req.user.id,
    chatId,
    content,
  });

  return success(res, {
    status: 201,
    message: 'Message sent',
    data: { message },
  });
});

const list = asyncHandler(async (req, res) => {
  const { page, limit } = req.query;
  const result = await messageService.listMessages({
    userId: req.user.id,
    chatId: req.params.chatId,
    page,
    limit,
  });

  return success(res, {
    status: 200,
    message: 'Message list',
    data: result,
  });
});

module.exports = { send, list };
