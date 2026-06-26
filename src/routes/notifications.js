'use strict';
/**
 * src/routes/notifications.js
 */
const router = require('express').Router();
const ctrl   = require('../controllers/notificationsController');
const auth   = require('../middleware/auth');

// IMPORTANT: specific routes before the generic /:id ones
router.get   ('/settings',   auth, ctrl.getSettings);
router.put   ('/settings',   auth, ctrl.updateSettings);

router.get   ('/',           auth, ctrl.list);
router.put   ('/read-all',   auth, ctrl.markAllRead);
router.put   ('/:id/read',   auth, ctrl.markRead);
router.delete('/:id',        auth, ctrl.remove);

module.exports = router;
