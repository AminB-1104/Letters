'use strict';

const mongoose = require('mongoose');
const User = require('../models/user-model');
const { toUserSummary, assertObjectId } = require('./user-service');

function makeError(status, message) {
  const err = new Error(message);
  err.status = status;
  err.expose = true;
  return err;
}

async function loadUserOr404(userId, label = 'User') {
  const doc = await User.findById(userId);
  if (!doc) {
    throw makeError(404, `${label} not found`);
  }
  return doc;
}

async function sendRequest({ fromUserId, toUserId }) {
  assertObjectId(fromUserId, 'sender id');
  assertObjectId(toUserId, 'recipient id');

  if (String(fromUserId) === String(toUserId)) {
    throw makeError(400, 'You cannot send a request to yourself');
  }

  const [sender, recipient] = await Promise.all([
    loadUserOr404(fromUserId, 'Sender'),
    loadUserOr404(toUserId, 'Recipient'),
  ]);

  if (sender.friends.some((id) => id.equals(recipient._id))) {
    throw makeError(409, 'You are already friends with this user');
  }
  if (sender.sentRequests.some((id) => id.equals(recipient._id))) {
    throw makeError(409, 'Friend request already sent');
  }
  if (sender.receivedRequests.some((id) => id.equals(recipient._id))) {
    throw makeError(409, 'This user already sent you a request — accept it instead');
  }

  await Promise.all([
    User.updateOne({ _id: sender._id }, { $addToSet: { sentRequests: recipient._id } }),
    User.updateOne({ _id: recipient._id }, { $addToSet: { receivedRequests: sender._id } }),
  ]);

  return { ok: true };
}

async function acceptRequest({ userId, requesterId }) {
  assertObjectId(userId, 'user id');
  assertObjectId(requesterId, 'requester id');

  if (String(userId) === String(requesterId)) {
    throw makeError(400, 'Invalid request');
  }

  const user = await loadUserOr404(userId, 'User');

  if (!user.receivedRequests.some((id) => id.equals(requesterId))) {
    throw makeError(404, 'No pending request from this user');
  }

  const requesterObjectId = new mongoose.Types.ObjectId(requesterId);

  await Promise.all([
    User.updateOne(
      { _id: user._id },
      {
        $pull: { receivedRequests: requesterObjectId },
        $addToSet: { friends: requesterObjectId },
      }
    ),
    User.updateOne(
      { _id: requesterObjectId },
      {
        $pull: { sentRequests: user._id },
        $addToSet: { friends: user._id },
      }
    ),
  ]);

  return { ok: true };
}

async function declineRequest({ userId, requesterId }) {
  assertObjectId(userId, 'user id');
  assertObjectId(requesterId, 'requester id');

  const user = await loadUserOr404(userId, 'User');

  if (!user.receivedRequests.some((id) => id.equals(requesterId))) {
    throw makeError(404, 'No pending request from this user');
  }

  const requesterObjectId = new mongoose.Types.ObjectId(requesterId);

  await Promise.all([
    User.updateOne({ _id: user._id }, { $pull: { receivedRequests: requesterObjectId } }),
    User.updateOne({ _id: requesterObjectId }, { $pull: { sentRequests: user._id } }),
  ]);

  return { ok: true };
}

async function removeFriend({ userId, friendId }) {
  assertObjectId(userId, 'user id');
  assertObjectId(friendId, 'friend id');

  const user = await loadUserOr404(userId, 'User');

  if (!user.friends.some((id) => id.equals(friendId))) {
    throw makeError(404, 'Friendship not found');
  }

  const friendObjectId = new mongoose.Types.ObjectId(friendId);

  await Promise.all([
    User.updateOne({ _id: user._id }, { $pull: { friends: friendObjectId } }),
    User.updateOne({ _id: friendObjectId }, { $pull: { friends: user._id } }),
  ]);

  return { ok: true };
}

async function listFriends({ userId, page = 1, limit = 50 }) {
  assertObjectId(userId, 'user id');

  const safePage = Math.max(1, Number.parseInt(page, 10) || 1);
  const safeLimit = Math.min(100, Math.max(1, Number.parseInt(limit, 10) || 50));
  const skip = (safePage - 1) * safeLimit;

  const user = await User.findById(userId).populate({
    path: 'friends',
    select: 'username displayName avatar',
    options: { skip, limit: safeLimit, sort: { username: 1 } },
  });

  if (!user) {
    throw makeError(404, 'User not found');
  }

  return {
    results: user.friends.map(toUserSummary),
    page: safePage,
    limit: safeLimit,
  };
}

async function listRequests({ userId }) {
  assertObjectId(userId, 'user id');

  const user = await User.findById(userId)
    .populate({ path: 'receivedRequests', select: 'username displayName avatar' })
    .populate({ path: 'sentRequests', select: 'username displayName avatar' });

  if (!user) {
    throw makeError(404, 'User not found');
  }

  return {
    incoming: user.receivedRequests.map(toUserSummary),
    outgoing: user.sentRequests.map(toUserSummary),
  };
}

async function resolveUserId({ userId, username }) {
  if (userId) {
    assertObjectId(userId, 'user id');
    return userId;
  }
  if (typeof username === 'string' && username.trim().length > 0) {
    const doc = await User.findOne({ username: username.toLowerCase() }).select('_id');
    if (!doc) {
      throw makeError(404, 'User not found');
    }
    return doc._id.toString();
  }
  throw makeError(400, 'userId or username is required');
}

module.exports = {
  sendRequest,
  acceptRequest,
  declineRequest,
  removeFriend,
  listFriends,
  listRequests,
  resolveUserId,
};
