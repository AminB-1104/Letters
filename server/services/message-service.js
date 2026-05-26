'use strict';

const Chat = require('../models/chat-model');
const Message = require('../models/message-model');
const { assertObjectId } = require('./user-service');
const chatService = require('./chat-service');

const MAX_MESSAGE_LENGTH = 2000;

function makeError(status, message) {
  const err = new Error(message);
  err.status = status;
  err.expose = true;
  return err;
}

// Content is stored verbatim and rendered as plain text in Flutter (`Text(...)`)
// so HTML/JS escaping is unnecessary. Trim + length checks cover spec §11 Rule 4.
function toMessage(doc) {
  return {
    id: doc._id.toString(),
    chatId: doc.chatId.toString(),
    sender: doc.sender.toString(),
    content: doc.content,
    type: doc.type,
    createdAt: doc.createdAt,
  };
}

async function sendMessage({ userId, chatId, content }) {
  assertObjectId(userId, 'user id');
  assertObjectId(chatId, 'chat id');

  const trimmed = typeof content === 'string' ? content.trim() : '';
  if (trimmed.length === 0) {
    throw makeError(400, 'Message cannot be empty');
  }
  if (trimmed.length > MAX_MESSAGE_LENGTH) {
    throw makeError(400, `Message exceeds ${MAX_MESSAGE_LENGTH} characters`);
  }

  await chatService.assertParticipant({ userId, chatId });

  const msg = await Message.create({
    chatId,
    sender: userId,
    content: trimmed,
    type: 'text',
  });

  // Bumps Chat.updatedAt via { timestamps: true } so /chats/list reorders.
  await Chat.updateOne({ _id: chatId }, { lastMessage: msg._id });

  return toMessage(msg);
}

async function listMessages({ userId, chatId, page = 1, limit = 30 }) {
  assertObjectId(userId, 'user id');
  assertObjectId(chatId, 'chat id');

  await chatService.assertParticipant({ userId, chatId });

  const safePage = Math.max(1, Number.parseInt(page, 10) || 1);
  const safeLimit = Math.min(100, Math.max(1, Number.parseInt(limit, 10) || 30));

  const docs = await Message.find({ chatId })
    .sort({ createdAt: -1 })
    .skip((safePage - 1) * safeLimit)
    .limit(safeLimit)
    .lean();

  return {
    results: docs.map((d) => ({
      id: d._id.toString(),
      chatId: d.chatId.toString(),
      sender: d.sender.toString(),
      content: d.content,
      type: d.type,
      createdAt: d.createdAt,
    })),
    page: safePage,
    limit: safeLimit,
  };
}

module.exports = { sendMessage, listMessages };
