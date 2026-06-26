'use strict';
const router = require('express').Router();
const ctrl   = require('../controllers/homeController');
const auth   = require('../middleware/auth');

const optAuth = (req, res, next) => {
  const h = req.headers.authorization;
  if (h && h.startsWith('Bearer ')) return auth(req, res, next);
  next();
};

router.get('/', optAuth, ctrl.getHomeData);
module.exports = router;
