// Supabase Edge Function: send-push-notification
// Triggered by database changes to send FCM push notifications to users.
//
// Environment variables:
// - FCM_SERVICE_ACCOUNT: Full JSON service account key from Firebase
//   (Project Settings → Service Accounts → Generate New Private Key)
//
// Called via: supabase.functions.invoke('send-push-notification', body)
// Or via DB webhook: on INSERT to notifications, messages, jobs
//
// Body: {
//   "user_id": "uuid",
//   "title": "Notification title",
//   "body": "Notification body",
//   "data": { "type": "new_message|job_match|status_update|application", "id": "..." }
// }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

interface PushPayload {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface FcmResponse {
  success: boolean;
  message_id?: string;
  error?: string;
}

interface ServiceAccount {
  project_id: string;
  private_key: string;
  client_email: string;
  [key: string]: unknown;
}

let _cachedToken: { token: string; expiresAt: number } | null = null;

/**
 * Get an OAuth2 access token from the Firebase service account.
 * Uses Google's OAuth2 server-to-server flow (JWT assertion → access token).
 * Tokens are cached and auto-refreshed.
 */
async function getAccessToken(): Promise<string> {
  // Return cached token if still valid (with 5 min buffer)
  if (_cachedToken && _cachedToken.expiresAt > Date.now() + 300_000) {
    return _cachedToken.token;
  }

  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT not configured");

  const sa: ServiceAccount = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);

  // Build JWT assertion
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  // Base64url encode helper
  const b64 = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(
      /\//g,
      "_",
    );

  const headerB64 = b64(header);
  const payloadB64 = b64(payload);
  const toSign = `${headerB64}.${payloadB64}`;

  // Convert PEM private key to ArrayBuffer (PKCS#8 DER format)
  const pemToBinary = (pem: string): ArrayBuffer => {
    const b64Content = pem
      .replace(/-----BEGIN PRIVATE KEY-----/, "")
      .replace(/-----END PRIVATE KEY-----/, "")
      .replace(/\s/g, "");
    const binaryStr = atob(b64Content);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }
    return bytes.buffer;
  };

  // Import the private key and sign
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    privateKey,
    new TextEncoder().encode(toSign),
  );

  // Encode signature as base64url
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${toSign}.${sigB64}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  if (!tokenResponse.ok || !tokenData.access_token) {
    throw new Error(
      `Failed to get access token: ${tokenData.error || tokenResponse.status}`,
    );
  }

  // Cache the token (expires_in is typically 3600s)
  _cachedToken = {
    token: tokenData.access_token,
    expiresAt: now + (tokenData.expires_in || 3600),
  };

  return tokenData.access_token;
}

/**
 * Get the FCM device token for a user from the database.
 */
async function getUserFcmToken(userId: string): Promise<string | null> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

  const response = await fetch(
    `${supabaseUrl}/rest/v1/rpc/get_user_fcm_token`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": supabaseKey,
        "Authorization": `Bearer ${supabaseKey}`,
      },
      body: JSON.stringify({ p_user_id: userId }),
    },
  );

  if (!response.ok) {
    // Fallback: query the fcm_tokens table directly
    const fallback = await fetch(
      `${supabaseUrl}/rest/v1/fcm_tokens?user_id=eq.${userId}&select=token&order=created_at.desc&limit=1`,
      {
        headers: {
          "apikey": supabaseKey,
          "Authorization": `Bearer ${supabaseKey}`,
        },
      },
    );
    if (!fallback.ok) return null;
    const tokens = await fallback.json();
    if (!Array.isArray(tokens) || tokens.length === 0) return null;
    return tokens[0]?.token || null;
  }

  const data = await response.json();
  return data?.token || null;
}

/**
 * Send a push notification via FCM HTTP v1 API.
 */
async function sendFcmNotification(
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<FcmResponse> {
  const accessToken = await getAccessToken();

  const v1Message = {
    message: {
      token,
      notification: {
        title,
        body,
      },
      data: data || undefined,
      android: {
        priority: "high" as const,
        notification: {
          channel_id: "default",
          priority: "high" as const,
          visibility: "public" as const,
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "content-available": 1,
          },
        },
      },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(v1Message),
    },
  );

  if (response.ok) {
    const result = await response.json();
    return { success: true, message_id: result.name };
  }

  // Handle specific error cases
  const errorBody = await response.text();
  let errorMsg = `HTTP ${response.status}`;
  try {
    const err = JSON.parse(errorBody);
    errorMsg = err.error?.message || err.error?.status || errorMsg;

    // Token not registered — clean up
    if (errorMsg.includes("UNREGISTERED") || errorMsg.includes("NOT_FOUND")) {
      console.warn(`[FCM] Token not registered, should remove: ${token}`);
    }
  } catch {
    errorMsg = errorBody || errorMsg;
  }

  return { success: false, error: errorMsg };
}

serve(async (req) => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const payload: PushPayload = await req.json();

    if (!payload.user_id || !payload.title) {
      return new Response(
        JSON.stringify({ error: "user_id and title are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    console.log(
      `[send-push] Sending to user ${payload.user_id}: ${payload.title}`,
    );

    // Get the user's FCM token
    const token = await getUserFcmToken(payload.user_id);
    if (!token) {
      console.log(`[send-push] No FCM token found for user ${payload.user_id}`);
      return new Response(
        JSON.stringify({
          success: false,
          error: "No FCM token found for user",
        }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    // Get project ID from the service account
    const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!raw) {
      return new Response(
        JSON.stringify({ success: false, error: "FCM_SERVICE_ACCOUNT not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }
    const sa: ServiceAccount = JSON.parse(raw);

    // Send the notification via FCM v1
    const result = await sendFcmNotification(
      sa.project_id,
      token,
      payload.title,
      payload.body,
      payload.data,
    );

    if (result.success) {
      console.log(`[send-push] Sent successfully: ${result.message_id}`);
    } else {
      console.error(`[send-push] Failed: ${result.error}`);
    }

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[send-push] Error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
