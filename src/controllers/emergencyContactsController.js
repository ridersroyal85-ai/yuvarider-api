'use strict';
/**
 * src/controllers/emergencyContactsController.js
 *
 * CRUD for /api/v1/emergency-contacts
 *
 * GET    /                 → list all contacts for the authenticated user
 * POST   /                 → add a new contact
 * PUT    /:id              → update an existing contact
 * DELETE /:id              → delete a contact
 */

const pool = require('../config/db');

// ── GET /api/v1/emergency-contacts ────────────────────────────────────────────
exports.list = async (req, res, next) => {
  try {
    const r = await pool.query(
      `SELECT id, name, phone, relationship, created_at
       FROM   public.emergency_contacts
       WHERE  user_id = $1
       ORDER  BY created_at ASC`,
      [req.user.id]
    );
    res.json({ success: true, contacts: r.rows });
  } catch (err) { next(err); }
};

// ── POST /api/v1/emergency-contacts ───────────────────────────────────────────
exports.create = async (req, res, next) => {
  try {
    const { name, phone, relationship } = req.body;

    if (!name || !name.trim())
      return res.status(400).json({ success: false, message: 'name is required' });
    if (!phone || !phone.trim())
      return res.status(400).json({ success: false, message: 'phone is required' });
    if (!relationship || !relationship.trim())
      return res.status(400).json({ success: false, message: 'relationship is required' });

    const r = await pool.query(
      `INSERT INTO public.emergency_contacts (user_id, name, phone, relationship)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, phone, relationship, created_at`,
      [req.user.id, name.trim(), phone.trim(), relationship.trim()]
    );

    // Update the legacy single-contact cache on users table
    await pool.query(
      `UPDATE public.users SET emergency_contact = $1 WHERE id = $2`,
      [phone.trim(), req.user.id]
    );

    res.status(201).json({ success: true, contact: r.rows[0] });
  } catch (err) { next(err); }
};

// ── PUT /api/v1/emergency-contacts/:id ────────────────────────────────────────
exports.update = async (req, res, next) => {
  try {
    const { name, phone, relationship } = req.body;

    const r = await pool.query(
      `UPDATE public.emergency_contacts
       SET    name         = COALESCE($1, name),
              phone        = COALESCE($2, phone),
              relationship = COALESCE($3, relationship),
              updated_at   = NOW()
       WHERE  id = $4 AND user_id = $5
       RETURNING id, name, phone, relationship, created_at, updated_at`,
      [name?.trim() ?? null, phone?.trim() ?? null, relationship?.trim() ?? null,
       req.params.id, req.user.id]
    );

    if (!r.rows.length)
      return res.status(404).json({ success: false, message: 'Contact not found' });

    res.json({ success: true, contact: r.rows[0] });
  } catch (err) { next(err); }
};

// ── DELETE /api/v1/emergency-contacts/:id ─────────────────────────────────────
exports.remove = async (req, res, next) => {
  try {
    const r = await pool.query(
      `DELETE FROM public.emergency_contacts
       WHERE id = $1 AND user_id = $2
       RETURNING id`,
      [req.params.id, req.user.id]
    );

    if (!r.rows.length)
      return res.status(404).json({ success: false, message: 'Contact not found' });

    // Refresh the legacy cache — point it at the most recent remaining contact
    await pool.query(
      `UPDATE public.users u
       SET    emergency_contact = (
                SELECT phone FROM public.emergency_contacts
                WHERE  user_id = $1
                ORDER  BY created_at DESC
                LIMIT  1
              )
       WHERE  u.id = $1`,
      [req.user.id]
    );

    res.json({ success: true, deleted: req.params.id });
  } catch (err) { next(err); }
};
