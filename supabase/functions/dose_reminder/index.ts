import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
// UPGRADED to v12.1.1 which completely removes the dead /batch endpoint
import admin from "npm:firebase-admin@12.1.1";

const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
if (!serviceAccountStr) {
  throw new Error('Missing FIREBASE_SERVICE_ACCOUNT secret.');
}

const serviceAccount = JSON.parse(serviceAccountStr);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { data: tokens, error } = await supabase.from('user_tokens').select('fcm_token');
    
    if (error) throw error;
    if (!tokens || tokens.length === 0) {
      return new Response("No devices registered.", { status: 200 });
    }

    const fcmTokens = tokens.map(t => t.fcm_token);

    const payload = {
      notification: {
        title: "💊 Dose Reminder!",
        body: "It is time to take your medication. Open the app to log your dose.",
      },
      tokens: fcmTokens,
    };

    // UPGRADED: Using the modern HTTP v1 loop instead of the deprecated batch API
    const response = await admin.messaging().sendEachForMulticast(payload);

    return new Response(
      JSON.stringify({ success: true, message: "Notifications sent!", details: response }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});