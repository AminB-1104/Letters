'use strict';

const asyncHandler = require('../utils/async-handler');
const { success } = require('../utils/api-response');
const authService = require('../services/auth-service');

function badRequest(message) {
  const err = new Error(message);
  err.status = 400;
  err.expose = true;
  return err;
}

function requireString(value, field, { min, max } = {}) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw badRequest(`${field} is required`);
  }
  if (min != null && value.length < min) {
    throw badRequest(`${field} must be at least ${min} characters`);
  }
  if (max != null && value.length > max) {
    throw badRequest(`${field} must be at most ${max} characters`);
  }
}

const register = asyncHandler(async (req, res) => {
  const { username, displayName, password } = req.body || {};
  requireString(username, 'Username', { min: 3, max: 20 });
  requireString(displayName, 'Display name', { min: 2, max: 30 });
  requireString(password, 'Password', { min: 6 });

  const { user, token } = await authService.registerUser({
    username,
    displayName,
    password,
  });

  return success(res, {
    status: 201,
    message: 'Account created',
    data: { user, token },
  });
});

const login = asyncHandler(async (req, res) => {
  const { username, password } = req.body || {};
  requireString(username, 'Username');
  requireString(password, 'Password');

  const { user, token } = await authService.loginUser({ username, password });

  return success(res, {
    status: 200,
    message: 'Login successful',
    data: { user, token },
  });
});

const me = asyncHandler(async (req, res) => {
  const user = await authService.getCurrentUser(req.user.id);
  return success(res, {
    status: 200,
    message: 'Current user',
    data: { user },
  });
});

module.exports = { register, login, me };
