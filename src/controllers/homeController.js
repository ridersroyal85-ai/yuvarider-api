/**
 * homeController.js
 * GET /api/v1/home  →  single aggregated payload for HomeScreen
 */
'use strict';
const pool = require('../config/db');

function imgUrl(val, req) {
  if (!val) return null;
  if (/^https?:\/\//.test(val)) return val;
  const base = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
  return `${base}/uploads/${val}`;
}

exports.getHomeData = async (req, res, next) => {
  const userId = req.user?.id ?? null;
  try {
    const now        = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().slice(0, 10);
    const monthEnd   = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().slice(0, 10);

    // ── 1. User rank this month ──────────────────────────────────────────────
    let userRank = null;
    if (userId) {
      const { rows } = await pool.query(`
        WITH monthly AS (
          SELECT u.id, u.name, u.avatar_url,
            COALESCE(SUM(r.distance_km),0)::NUMERIC AS km,
            COUNT(rp.id)::INT AS rides
          FROM users u
          LEFT JOIN ride_participants rp ON rp.user_id = u.id AND rp.status = 'confirmed'
          LEFT JOIN rides r ON r.id = rp.ride_id
            AND r.status IN ('completed','active')
            AND r.start_date BETWEEN $1 AND $2
          GROUP BY u.id
        ), ranked AS (
          SELECT *, RANK() OVER (ORDER BY km DESC) AS rank FROM monthly
        )
        SELECT rank, km, rides, name, avatar_url FROM ranked WHERE id = $3
      `, [monthStart, monthEnd, userId]);

      if (rows[0]) {
        const r = rows[0];
        userRank = {
          rank:          +r.rank,
          km_this_month: +r.km,
          ride_count:    r.rides,
          name:          r.name,
          avatar_url:    imgUrl(r.avatar_url, req),
        };
      }
    }

    // ── 2. Monthly Race top-5 ────────────────────────────────────────────────
    const { rows: raceRows } = await pool.query(`
      SELECT u.id, u.name, u.avatar_url,
        COALESCE(SUM(r.distance_km),0)::NUMERIC AS km,
        COUNT(rp.id)::INT AS rides
      FROM users u
      LEFT JOIN ride_participants rp ON rp.user_id = u.id AND rp.status = 'confirmed'
      LEFT JOIN rides r ON r.id = rp.ride_id
        AND r.status IN ('completed','active')
        AND r.start_date BETWEEN $1 AND $2
      GROUP BY u.id ORDER BY km DESC LIMIT 5
    `, [monthStart, monthEnd]);

    const monthlyRace = raceRows.map((r, i) => ({
      rank: i + 1, user_id: r.id, name: r.name,
      avatar_url: imgUrl(r.avatar_url, req),
      km_this_month: +r.km, ride_count: r.rides, is_me: r.id === userId,
    }));

    const km_behind_first = (userRank && monthlyRace.length > 0 && userRank.rank > 1)
      ? Math.max(0, monthlyRace[0].km_this_month - userRank.km_this_month)
      : null;
    if (userRank) userRank.km_behind_first = km_behind_first;

    // ── 3. Live Rides ────────────────────────────────────────────────────────
    const { rows: liveRows } = await pool.query(`
      SELECT r.id, r.name, r.source, r.destination, r.cover_photo,
        r.distance_km, r.ride_type, r.status, r.start_date, r.start_time,
        u.id AS rider_id, u.name AS rider_name, u.avatar_url AS rider_av,
        (SELECT COUNT(*) FROM ride_participants rp2
          WHERE rp2.ride_id = r.id AND rp2.status='confirmed')::INT AS pax,
        CASE WHEN $1::UUID IS NOT NULL AND EXISTS (
          SELECT 1 FROM ride_participants rp3
          WHERE rp3.ride_id = r.id AND rp3.user_id = $1
        ) THEN 'Friend' ELSE 'Public' END AS rel
      FROM rides r JOIN users u ON u.id = r.created_by
      WHERE r.status = 'active'
      ORDER BY r.updated_at DESC LIMIT 6
    `, [userId]);

    const liveRides = liveRows.map(r => ({
      id: r.id, name: r.name, source: r.source, destination: r.destination,
      cover_photo: imgUrl(r.cover_photo, req),
      distance_km: r.distance_km ? +r.distance_km : null,
      ride_type: r.ride_type, status: r.status,
      start_date: r.start_date, start_time: r.start_time,
      participant_count: r.pax, relation_type: r.rel,
      rider: { id: r.rider_id, name: r.rider_name, avatar_url: imgUrl(r.rider_av, req) },
    }));

    // ── 4. Marketplace ───────────────────────────────────────────────────────
    const { rows: mktRows } = await pool.query(`
      SELECT ml.id, ml.title, ml.price, ml.mrp, ml.condition, ml.category,
        ml.location, ml.is_featured, ml.is_hot_deal, ml.image_urls, ml.created_at,
        u.name AS seller_name, u.avatar_url AS seller_av
      FROM marketplace_listings ml JOIN users u ON u.id = ml.seller_id
      WHERE ml.status = 'active'
      ORDER BY ml.created_at DESC LIMIT 6
    `);

    const marketplace = mktRows.map(m => {
      let img = null;
      try {
        const arr = Array.isArray(m.image_urls) ? m.image_urls : JSON.parse(m.image_urls || '[]');
        if (arr[0]) img = imgUrl(arr[0], req);
      } catch {}
      return {
        id: m.id, title: m.title, price: +m.price, mrp: m.mrp ? +m.mrp : null,
        condition: m.condition, category: m.category, location: m.location,
        is_featured: m.is_featured, is_hot_deal: m.is_hot_deal,
        image_url: img, created_at: m.created_at,
        seller_name: m.seller_name, seller_avatar: imgUrl(m.seller_av, req),
      };
    });

    // ── 5. Upcoming Rides ────────────────────────────────────────────────────
    const { rows: upRows } = await pool.query(`
      SELECT r.id, r.name, r.source, r.destination, r.start_date, r.start_time,
        r.distance_km, r.duration_hrs, r.ride_type, r.scenic, r.is_paid, r.entry_fee,
        r.max_participants, r.cloned_count, r.cover_photo, r.cover_photo_name,
        (SELECT COUNT(*) FROM ride_participants rp WHERE rp.ride_id = r.id AND rp.status='confirmed')::INT AS pax
      FROM rides r
      WHERE r.status = 'upcoming' AND r.start_date >= CURRENT_DATE
      ORDER BY r.start_date ASC, r.start_time ASC LIMIT 5
    `);

    const upcomingRides = upRows.map(r => ({
      id: r.id, name: r.name, source: r.source, destination: r.destination,
      start_date: r.start_date, start_time: r.start_time,
      distance_km: r.distance_km ? +r.distance_km : null,
      duration_hrs: r.duration_hrs ? +r.duration_hrs : null,
      ride_type: r.ride_type, scenic: r.scenic,
      is_paid: r.is_paid, entry_fee: +(r.entry_fee || 0),
      max_participants: r.max_participants, cloned_count: r.cloned_count,
      cover_photo: imgUrl(r.cover_photo, req), cover_photo_name: r.cover_photo_name,
      participant_count: r.pax,
    }));

    // ── 6. Famous Groups ─────────────────────────────────────────────────────
    const { rows: grpRows } = await pool.query(`
      SELECT g.id, g.name, g.description, g.location, g.cover_image, g.is_public,
        g.member_count, g.ride_count, g.total_km,
        CASE WHEN $1::UUID IS NOT NULL AND EXISTS (
          SELECT 1 FROM group_members gm WHERE gm.group_id=g.id AND gm.user_id=$1
        ) THEN true ELSE false END AS is_member,
        CASE WHEN $1::UUID IS NOT NULL AND EXISTS (
          SELECT 1 FROM group_members gm WHERE gm.group_id=g.id AND gm.user_id=$1 AND gm.role='admin'
        ) THEN true ELSE false END AS is_admin
      FROM groups g WHERE g.is_public=TRUE
      ORDER BY g.total_km DESC LIMIT 5
    `, [userId]);

    const famousGroups = grpRows.map(g => ({
      id: g.id, name: g.name, description: g.description,
      location: g.location, cover_image: imgUrl(g.cover_image, req),
      is_public: g.is_public, member_count: g.member_count,
      ride_count: g.ride_count, total_km: +(g.total_km || 0),
      is_member: g.is_member, is_admin: g.is_admin,
    }));

    // ── 7. Famous Riders ─────────────────────────────────────────────────────
    const { rows: rdrRows } = await pool.query(`
      SELECT u.id, u.name, u.avatar_url, u.location, u.total_km, u.total_rides,
        (SELECT json_build_object('name',r2.name,'source',r2.source,
            'destination',r2.destination,'distance_km',r2.distance_km)
          FROM rides r2 JOIN ride_participants rp2 ON rp2.ride_id=r2.id
          WHERE rp2.user_id=u.id AND r2.status='completed'
          ORDER BY r2.start_date DESC LIMIT 1) AS last_ride
      FROM users u WHERE u.is_active=TRUE
      ORDER BY u.total_km DESC LIMIT 5
    `);

    const famousRiders = rdrRows.map(r => ({
      id: r.id, name: r.name, avatar_url: imgUrl(r.avatar_url, req),
      location: r.location, total_km: +(r.total_km || 0),
      total_rides: r.total_rides, last_ride: r.last_ride || null,
      is_me: r.id === userId,
    }));

    // ── 8. Activity Feed ─────────────────────────────────────────────────────
    const { rows: feedRows } = await pool.query(`
      (SELECT 'ride_completed' AS event_type, rp.joined_at AS event_time,
        u.id AS actor_id, u.name AS actor_name, u.avatar_url AS actor_av,
        r.name AS target_name, r.distance_km::TEXT AS meta
        FROM ride_participants rp
        JOIN users u ON u.id=rp.user_id
        JOIN rides r ON r.id=rp.ride_id
        WHERE r.status='completed' AND rp.status='confirmed'
        ORDER BY rp.joined_at DESC LIMIT 5)
      UNION ALL
      (SELECT 'group_joined', gm.joined_at,
        u.id, u.name, u.avatar_url, g.name, NULL
        FROM group_members gm
        JOIN users u ON u.id=gm.user_id
        JOIN groups g ON g.id=gm.group_id
        ORDER BY gm.joined_at DESC LIMIT 5)
      UNION ALL
      (SELECT 'item_sold', ml.updated_at,
        u.id, u.name, u.avatar_url, ml.title, ml.price::TEXT
        FROM marketplace_listings ml
        JOIN users u ON u.id=ml.seller_id
        WHERE ml.status='sold'
        ORDER BY ml.updated_at DESC LIMIT 5)
      ORDER BY event_time DESC LIMIT 10
    `);

    const activityFeed = feedRows.map(r => ({
      event_type: r.event_type, event_time: r.event_time,
      actor: { id: r.actor_id, name: r.actor_name, avatar_url: imgUrl(r.actor_av, req) },
      target_name: r.target_name, meta: r.meta,
    }));

    res.json({
      success: true,
      data: {
        user_rank: userRank, monthly_race: monthlyRace, km_behind_first,
        live_rides: liveRides, marketplace, upcoming_rides: upcomingRides,
        famous_groups: famousGroups, famous_riders: famousRiders,
        activity_feed: activityFeed,
      },
    });
  } catch (err) { next(err); }
};
