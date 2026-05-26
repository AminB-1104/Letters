'use strict';

const mongoose = require('mongoose');
const User = require('../models/user-model');

function makeError(status, message) {
  const err = new Error(message);
  err.status = status;
  err.expose = true;
  return err;
}

function assertObjectId(id, field = 'id') {
  if (!mongoose.Types.ObjectId.isValid(id)) {
    throw makeError(400, `Invalid ${field}`);
  }
}

function escapeRegex(input) {
  return input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function toUserSummary(doc) {
  return {
    id: doc._id.toString(),
    username: doc.username,
    displayName: doc.displayName,
    avatar: doc.avatar || '',
  };
}

function relationshipFor(targetDoc, viewerId) {
  if (targetDoc._id.equals(viewerId)) return 'self';
  if (targetDoc.friends.some((id) => id.equals(viewerId))) return 'friend';
  if (targetDoc.receivedRequests.some((id) => id.equals(viewerId))) return 'requestSent';
  if (targetDoc.sentRequests.some((id) => id.equals(viewerId))) return 'requestReceived';
  return 'none';
}

function toPublicProfile(doc, viewerId) {
  return {
    id: doc._id.toString(),
    username: doc.username,
    displayName: doc.displayName,
    avatar: doc.avatar || '',
    bio: doc.bio || '',
    createdAt: doc.createdAt,
    friendCount: doc.friends.length,
    relationship: relationshipFor(doc, viewerId),
  };
}

async function searchUsers({ query, viewerId, page = 1, limit = 20 }) {
  assertObjectId(viewerId, 'viewer id');

  const trimmed = typeof query === 'string' ? query.trim() : '';
  if (trimmed.length === 0) {
    throw makeError(400, 'Search query is required');
  }

  const safePage = Math.max(1, Number.parseInt(page, 10) || 1);
  const safeLimit = Math.min(50, Math.max(1, Number.parseInt(limit, 10) || 20));

  const regex = new RegExp(escapeRegex(trimmed.toLowerCase()), 'i');
  const docs = await User.find({
    username: regex,
    _id: { $ne: viewerId },
  })
    .select('username displayName avatar')
    .skip((safePage - 1) * safeLimit)
    .limit(safeLimit)
    .lean();

  return {
    results: docs.map((d) => ({
      id: d._id.toString(),
      username: d.username,
      displayName: d.displayName,
      avatar: d.avatar || '',
    })),
    page: safePage,
    limit: safeLimit,
  };
}

async function getProfileByUsername({ username, viewerId }) {
  if (typeof username !== 'string' || username.trim().length === 0) {
    throw makeError(400, 'Username is required');
  }
  assertObjectId(viewerId, 'viewer id');

  const doc = await User.findOne({ username: username.toLowerCase() });
  if (!doc) {
    throw makeError(404, 'User not found');
  }

  return toPublicProfile(doc, viewerId);
}

module.exports = {
  searchUsers,
  getProfileByUsername,
  toUserSummary,
  toPublicProfile,
  assertObjectId,
};
