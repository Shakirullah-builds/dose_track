import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import admin from "npm:firebase-admin@12.1.1";

const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
if (!serviceAccountStr) throw new Error('Missing FIREBASE_SERVICE_ACCOUNT secret.');
const serviceAccount = JSON.parse(serviceAccountStr);

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Get the current time and adjust for West Africa Time (UTC+1)
    const now = new Date();
    now.setHours(now.getHours() + 1); 
    
    // Format as HH:mm (e.g., "08:30" or "14:00")
    const currentHour = now.getHours().toString().padStart(2, '0');
    const currentMinute = now.getMinutes().toString().padStart(2, '0');
    const currentTimeString = `${currentHour}:${currentMinute}`; 

    // 2. Find ONLY the medications scheduled for this exact minute
    // FIX: Added 'id' and 'instructions' to the select query!
    const { data: dueMedications, error: medError } = await supabase
      .from('medications')
      .select('id, user_id, name, dosage, unit, instructions') 
      .ilike('scheduled_time', `%${currentTimeString}%`);

    if (medError) throw medError;

    // If nobody has a pill due right now, just exit quietly!
    if (!dueMedications || dueMedications.length === 0) {
      return new Response("No medications due at this minute.", { status: 200 });
    }

    // 3. Extract the unique User IDs who need a reminder right now
    const userIds = [...new Set(dueMedications.map(m => m.user_id))];

    // 4. Fetch the specific FCM tokens for users WHO HAVE NOTIFICATIONS ENABLED
    const { data: tokens, error: tokenError } = await supabase
      .from('user_tokens')
      .select('user_id, fcm_token') 
      .in('user_id', userIds)
      .eq('notifications_enabled', true);

    if (tokenError) throw tokenError;
    
    if (!tokens || tokens.length === 0) {
        return new Response("Tokens found, but all users have paused notifications.", { status: 200 });
    }

    // 5. Build personalized messages for EVERY single medication
    const messages: any[] = [];

    for (const med of dueMedications) {
      // Find the specific tokens for the user who owns THIS medication
      const userTokens = tokens.filter(t => t.user_id === med.user_id);
      
      if (userTokens.length > 0) {
        // Construct the personalized text!
        const title = `💊 Time for ${med.name} (${med.dosage}${med.unit})`;
        const body = med.instructions && med.instructions.trim() !== '' 
            ? `Note: ${med.instructions}` 
            : `Open DoseVault to log your dose.`;

        // Create a push notification for each of the user's devices
        for (const target of userTokens) {
          messages.push({
            token: target.fcm_token,
            notification: {
              title: title,
              body: body,
            },
            data: {
              // We pass the ID silently in the background. We need this for the Action Buttons!
              medicationId: med.id, 
              action: 'dose_reminder'
            }
          });
        }
      }
    }

    // 6. Fire the sniper shots! 
    const response = await admin.messaging().sendEach(messages);

    return new Response(
      JSON.stringify({ success: true, messagesSent: messages.length, details: response }),
      { headers: { "Content-Type": "application/json" } }
    );

  // FIX: Added the missing catch block to close the function properly!
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});