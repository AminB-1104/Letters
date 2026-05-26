'use strict';

const mongoose = require('mongoose');
const Chat = require('../models/chat-model');
const User = require('../models/user-model');
const { toUserSummary, assertObjectId } = require('./user-service');

function makeError(status, message) {
  const err = new Error(message);
  err.status = status;
  err.expose = true;
  return err;
}

// Canonical ordering for the participants pair so the compound unique index on
// (participants.0, participants.1) collapses both initiation directions onto a
// single row.
function sortedPair(aId, bId) {
  const a = String(aId);
  const b = String(bId);
  return a < b
    ? [new mongoose.Types.ObjectId(a), new mongoose.Types.ObjectId(b)]
    : [new mongoose.Types.ObjectId(b), new mongoose.Types.ObjectId(a)];
}

async function assertFriendship(userId, otherUserId) {
  const user = await User.findById(userId).select('friends');
  if (!user) {
    throw makeError(404, 'User not found');
  }
  if (!user.friends.some((id) => id.equals(otherUserId))) {
    throw makeError(403, 'You can only chat with existing friends');
  }
}

function toMessagePreview(msgDoc) {
  if (!msgDoc) return null;
  return {
    id: msgDoc._id.toString(),
    sender: msgDoc.sender ? msgDoc.sender.toString() : null,
    content: msgDoc.content,
    type: msgDoc.type,
    createdAt: msgDoc.createdAt,
  };
}

function toChatSummary(chatDoc, viewerId) {
  const viewerString = String(viewerId);
  const other = chatDoc.participants.find(
    (p) => String(p._id ?? p) !== viewerString
  );

  return {
    id: chatDoc._id.toString(),
    other: other && other.username ? toUserSummary(other) : null,
    lastMessage: toMessagePreview(chatDoc.lastMessage),
    createdAt: chatDoc.createdAt,
    updatedAt: chatDoc.updatedAt,
  };
}

async function loadChatForViewer(chatId) {
  return Chat.findById(chatId)
    .populate({ path: 'participants', select: 'username displayName avatar' })
    .populate({
      path: 'lastMessage',
      select: 'sender content type createdAt',
    });
}

async function createOrGetChat({ userId, otherUserId }) {
  assertObjectId(userId, 'user id');
  assertObjectId(otherUserId, 'other user id');

  if (String(userId) === String(otherUserId)) {
    throw makeError(400, 'You cannot start a chat with yourself');
  }

  await assertFriendship(userId, otherUserId);

  const [a, b] = sortedPair(userId, otherUserId);

  const existing = await Chat.findOne({
    'participants.0': a,
    'participants.1': b,
  });

  if (existing) {
    const populated = await loadChatForViewer(existing._id);
    return { chat: toChatSummary(populated, userId), created: false };
  }

  const created = await Chat.create({ participants: [a, b] });
  const populated = await loadChatForViewer(created._id);
  return { chat: toChatSummary(populated, userId), created: true };
}

async function listChats({ userId, page = 1, limit = 20 }) {
  assertObjectId(userId, 'user id');

  const safePage = Math.max(1, Number.parseInt(page, 10) || 1);
  const safeLimit = Math.min(50, Math.max(1, Number.parseInt(limit, 10) || 20));

  const docs = await Chat.find({ participants: userId })
    .sort({ updatedAt: -1 })
    .skip((safePage - 1) * safeLimit)
    .limit(safeLimit)
    .populate({ path: 'participants', select: 'username displayName avatar' })
    .populate({
      path: 'lastMessage',
      select: 'sender content type createdAt',
    });

  return {
    results: docs.map((d) => toChatSummary(d, userId)),
    page: safePage,
    limit: safeLimit,
  };
}

async function getChatById({ userId, chatId }) {
  assertObjectId(userId, 'user id');
  assertObjectId(chatId, 'chat id');

  const chat = await loadChatForViewer(chatId);
  if (!chat) {
    throw makeError(404, 'Chat not found');
  }

  const isParticipant = chat.participants.some(
    (p) => String(p._id ?? p) === String(userId)
  );
  if (!isParticipant) {
    throw makeError(403, 'You are not a participant in this chat');
  }

  return toChatSummary(chat, userId);
}

async function assertParticipant({ userId, chatId }) {
  assertObjectId(userId, 'user id');
  assertObjectId(chatId, 'chat id');

  const chat = await Chat.findById(chatId).select('participants');
  if (!chat) {
    throw makeError(404, 'Chat not found');
  }

  const isParticipant = chat.participants.some((p) => p.equals(userId));
  if (!isParticipant) {
    throw makeError(403, 'You are not a participant in this chat');
  }

  return chat;
}

module.exports = {
  createOrGetChat,
  listChats,
  getChatById,
  assertParticipant,
  toChatSummary,
  toMessagePreview,
};
