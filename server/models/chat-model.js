'use strict';

const mongoose = require('mongoose');

const chatSchema = new mongoose.Schema(
  {
    participants: {
      type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      required: true,
      validate: {
        validator: (arr) => Array.isArray(arr) && arr.length === 2,
        message: 'A private chat must have exactly two participants',
      },
    },
    lastMessage: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Message',
      default: null,
    },
  },
  { timestamps: true }
);

// Enforce "only one chat between any two users" at the DB layer. The service
// stores participants sorted ascending by ObjectId string before inserting, so
// the (participants.0, participants.1) pair is canonical.
chatSchema.index({ 'participants.0': 1, 'participants.1': 1 }, { unique: true });

// "list my chats" query — find by membership, sorted newest-first.
chatSchema.index({ participants: 1, updatedAt: -1 });

module.exports = mongoose.model('Chat', chatSchema);
