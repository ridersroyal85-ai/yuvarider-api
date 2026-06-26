'use strict';
/**
 * src/controllers/notificationsController.js
 *
 * GET    /api/v1/notifications              → list (with unread count)
 * PUT    /api/v1/notifications/:id/read      → mark one as read
 * PUT    /api/v1/notifications/read-all      → mark all as read
 * DELETE /api/v1/notifications/:id           → delete one
 *
 * GET    /api/v1/notifications/settings      → get toggle preferences
 * PUT    /api/v1/notifications/settings      → update toggle preferences
 */

const pool = require('../config/db');

// Icon/colour mapping lives on the frontend; backend only stores `type`.

// ── GET /api/v1/notifications ─────────────────────────────────────────────────
exports.list = async (req, res, next) => {
  try {
    const uid = req.user.id;

    const [notifRes, unreadRes] = await Promise.all([
      pool.query(
        `SELECT id, type, title, body, is_read, meta, created_at
         FROM   public.notifications
         WHERE  user_id = $1
         ORDER  BY created_at DESC
         LIMIT  100`,
        [uid]
      ),
      pool.query(
        `SELECT COUNT(*) AS cnt FROM public.notifications WHERE user_id = $1 AND is_read = FALSE`,
        [uid]
      ),
    ]);

    res.json({
      success: true,
      notifications: notifRes.rows,
      unread_count: parseInt(unreadRes.rows[0].cnt) || 0,
    });
  } catch (err) { next(err); }
};

// ── PUT /api/v1/notifications/:id/read ────────────────────────────────────────
exports.markRead = async (req, res, next) => {
  try {
    const r = await pool.query(
      `UPDATE public.notifications
       SET    is_read = TRUE
       WHERE  id = $1 AND user_id = $2
       RETURNING id, is_read`,
      [req.params.id, req.user.id]
    );
    if (!r.rows.length)
      return res.status(404).json({ success: false, message: 'Notification not found' });

    res.json({ success: true, notification: r.rows[0] });
  } catch (err) { next(err); }
};

// ── PUT /api/v1/notifications/read-all ────────────────────────────────────────
exports.markAllRead = async (req, res, next) => {
  try {
    const r = await pool.query(
      `UPDATE public.notifications
       SET    is_read = TRUE
       WHERE  user_id = $1 AND is_read = FALSE
       RETURNING id`,
      [req.user.id]
    );
    res.json({ success: true, updated_count: r.rows.length });
  } catch (err) { next(err); }
};

// ── DELETE /api/v1/notifications/:id ──────────────────────────────────────────
exports.remove = async (req, res, next) => {
  try {
    const r = await pool.query(
      `DELETE FROM public.notifications WHERE id = $1 AND user_id = $2 RETURNING id`,
      [req.params.id, req.user.id]
    );
    if (!r.rows.length)
      return res.status(404).json({ success: false, message: 'Notification not found' });

    res.json({ success: true, deleted: req.params.id });
  } catch (err) { next(err); }
};

// ── GET /api/v1/notifications/settings ────────────────────────────────────────
exports.getSettings = async (req, res, next) => {
  try {
    let r = await pool.query(
      `SELECT service_reminders, insurance_alerts, ride_updates,
              expense_updates, payment_notifications
       FROM   public.notification_settings
       WHERE  user_id = $1`,
      [req.user.id]
    );

    // Auto-create defaults (all ON) if the user has none yet
    if (!r.rows.length) {
      r = await pool.query(
        `INSERT INTO public.notification_settings (user_id)
         VALUES ($1)
         RETURNING service_reminders, insurance_alerts, ride_updates,
                   expense_updates, payment_notifications`,
        [req.user.id]
      );
    }

    res.json({ success: true, settings: r.rows[0] });
  } catch (err) { next(err); }
};

// ── PUT /api/v1/notifications/settings ────────────────────────────────────────
exports.updateSettings = async (req, res, next) => {
  try {
    const {
      service_reminders, insurance_alerts, ride_updates,
      expense_updates, payment_notifications,
    } = req.body;

    const r = await pool.query(
      `INSERT INTO public.notification_settings
              (user_id, service_reminders, insurance_alerts, ride_updates,
               expense_updates, payment_notifications)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (user_id) DO UPDATE SET
              service_reminders     = EXCLUDED.service_reminders,
              insurance_alerts      = EXCLUDED.insurance_alerts,
              ride_updates          = EXCLUDED.ride_updates,
              expense_updates       = EXCLUDED.expense_updates,
              payment_notifications = EXCLUDED.payment_notifications,
              updated_at            = NOW()
       RETURNING service_reminders, insurance_alerts, ride_updates,
                 expense_updates, payment_notifications`,
      [
        req.user.id,
        service_reminders     ?? true,
        insurance_alerts      ?? true,
        ride_updates          ?? true,
        expense_updates       ?? true,
        payment_notifications ?? true,
      ]
    );

    res.json({ success: true, settings: r.rows[0] });
  } catch (err) { next(err); }
};
