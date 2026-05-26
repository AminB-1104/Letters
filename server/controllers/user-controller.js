'use strict';

const asyncHandler = require('../utils/async-handler');
const { success } = require('../utils/api-response');
const userService = require('../services/user-service');

const search = asyncHandler(async (req, res) => {
  const { q, page, limit } = req.query;
  const result = await userService.searchUsers({
    query: q,
    viewerId: req.user.id,
    page,
    limit,
  });

  return success(res, {
    status: 200,
    message: 'Search results',
    data: result,
  });
});

const profile = asyncHandler(async (req, res) => {
  const profileData = await userService.getProfileByUsername({
    username: req.params.username,
    viewerId: req.user.id,
  });

  return success(res, {
    status: 200,
    message: 'User profile',
    data: { user: profileData },
  });
});

module.exports = { search, profile };
