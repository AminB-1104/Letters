'use strict';

const asyncHandler = require('../utils/async-handler');
const { success } = require('../utils/api-response');
const friendService = require('../services/friend-service');

const sendRequest = asyncHandler(async (req, res) => {
  const { userId, username } = req.body || {};
  const targetId = await friendService.resolveUserId({ userId, username });

  await friendService.sendRequest({
    fromUserId: req.user.id,
    toUserId: targetId,
  });

  return success(res, {
    status: 201,
    message: 'Friend request sent',
    data: {},
  });
});

const acceptRequest = asyncHandler(async (req, res) => {
  const { userId } = req.body || {};
  await friendService.acceptRequest({
    userId: req.user.id,
    requesterId: userId,
  });

  return success(res, {
    status: 200,
    message: 'Friend request accepted',
    data: {},
  });
});

const declineRequest = asyncHandler(async (req, res) => {
  const { userId } = req.body || {};
  await friendService.declineRequest({
    userId: req.user.id,
    requesterId: userId,
  });

  return success(res, {
    status: 200,
    message: 'Friend request declined',
    data: {},
  });
});

const removeFriend = asyncHandler(async (req, res) => {
  const { userId } = req.body || {};
  await friendService.removeFriend({
    userId: req.user.id,
    friendId: userId,
  });

  return success(res, {
    status: 200,
    message: 'Friend removed',
    data: {},
  });
});

const listFriends = asyncHandler(async (req, res) => {
  const { page, limit } = req.query;
  const result = await friendService.listFriends({
    userId: req.user.id,
    page,
    limit,
  });

  return success(res, {
    status: 200,
    message: 'Friends list',
    data: result,
  });
});

const listRequests = asyncHandler(async (req, res) => {
  const result = await friendService.listRequests({ userId: req.user.id });

  return success(res, {
    status: 200,
    message: 'Friend requests',
    data: result,
  });
});

module.exports = {
  sendRequest,
  acceptRequest,
  declineRequest,
  removeFriend,
  listFriends,
  listRequests,
};
