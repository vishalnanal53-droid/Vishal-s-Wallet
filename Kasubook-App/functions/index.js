// ─── functions/index.js ──────────────────────────────────────────────────────
// Firebase Cloud Function: resetUserPassword
//
// SETUP STEPS:
// 1. cd functions
// 2. npm install firebase-admin firebase-functions cors
// 3. firebase deploy --only functions
// ─────────────────────────────────────────────────────────────────────────────

const functions = require('firebase-functions');
const admin     = require('firebase-admin');
const cors      = require('cors')({ origin: true });

admin.initializeApp();

exports.resetUserPassword = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {

    // Only allow POST
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    const { email, newPassword } = req.body;

    // ── Validate inputs ──────────────────────────────────────────────────
    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return res.status(400).json({ error: 'Valid email is required' });
    }

    if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    try {
      // ── Find user by email ───────────────────────────────────────────
      const userRecord = await admin.auth().getUserByEmail(email.trim().toLowerCase());

      // ── Update password using Admin SDK ──────────────────────────────
      await admin.auth().updateUser(userRecord.uid, {
        password: newPassword,
      });

      console.log(`[resetUserPassword] Password updated for uid=${userRecord.uid}`);

      return res.status(200).json({ success: true, message: 'Password updated successfully' });

    } catch (error) {
      console.error('[resetUserPassword] Error:', error);

      if (error.code === 'auth/user-not-found') {
        return res.status(404).json({ error: 'No account found with this email' });
      }

      if (error.code === 'auth/invalid-email') {
        return res.status(400).json({ error: 'Invalid email address' });
      }

      return res.status(500).json({ error: 'Failed to update password. Try again.' });
    }
  });
});