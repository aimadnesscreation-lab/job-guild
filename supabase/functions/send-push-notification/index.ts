// Supabase Edge Function: send-push-notification
// Triggered by database changes to send FCM push notifications to users.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { encodeBase64Url, TOKEN_EXPIRY_BUFFER_MS } from "../_shared/utils.ts";

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
 */
async function getAccessToken(): Promise<string> {
  const nowMs = Date.now();
  
  // Return cached token if still valid (with buffer)
  // Fix Bug #8: Also check if token is already expired or near expiry.
  if (_cachedToken && _cachedToken.expiresAt > nowMs + TOKEN_EXPIRY_BUFFER_MS) {
    return _cachedToken.token;
  }

  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT not configured");

  const sa: ServiceAccount = JSON.parse(raw);
  const nowSec = Math.floor(nowMs / 1000);

  // Build JWT assertion
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: nowSec + 3600,
    iat: nowSec,
  };

  // Fix Bug #1: Use proper Base64URL encoding from shared utils
  const headerB64 = encodeBase64Url(JSON.stringify(header));
  const payloadB64 = encodeBase64Url(JSON.stringify(payload));
  const toSign = `${headerB64}.${payloadB64}`;

  // Convert PEM private key to ArrayBuffer
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

  // Fix Bug #2: Use proper Base64URL encoding for signature (safe from stack overflow)
  const sigB64 = encodeBase64Url(new Uint8Array(signature));

  const jwt = `${toSign}.${sigB64}`;

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

  _cachedToken = {
    token: tokenData.access_token,
    expiresAt: (nowSec + (tokenData.expires_in || 3600)) * 1000,
  };

  return tokenData.access_token;
}

/**
 * Remove a dead FCM token from the database.
 */
async function removeDeadToken(token: string) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

  try {
    const response = await fetch(
      `${supabaseUrl}/rest/v1/fcm_tokens?token=eq.${encodeURIComponent(token)}`,
      {
        method: "DELETE",
        headers: {
          "apikey": supabaseKey,
          "Authorization": `Bearer ${supabaseKey}`,
        },
      },
    );
    if (response.ok) {
      console.log(`[send-push] Successfully removed dead token from database`);
    }
  } catch (e) {
    console.error(`[send-push] Failed to remove dead token: ${e}`);
  }
}

/**
 * Get the FCM device token for a user from the database.
 */
async function getUserFcmToken(userId: string): Promise<string | null> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

  // User-12: The RPC is the preferred way. If it returns null, we fallback once.
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
    const fallback = await fetch(
      `${supabaseUrl}/rest/v1/fcm_tokens?user_id=eq.${userId}&select=token&order=updated_at.desc&limit=1`,
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
  // RPC returns the token directly or a single-row list
  if (typeof data === "string") return data;
  return Array.isArray(data) ? data[0]?.token || null : data?.token || null;
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
      notification: { title, body },
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

  const errorBody = await response.text();
  let errorMsg = `HTTP ${response.status}`;
  try {
    const err = JSON.parse(errorBody);
    errorMsg = err.error?.message || err.error?.status || errorMsg;

    // Bug #13 Fix: Remove token from DB if it's dead
    if (errorMsg.includes("UNREGISTERED") || errorMsg.includes("NOT_FOUND")) {
      console.warn(`[FCM] Token dead: ${token}. Removing from DB.`);
      await removeDeadToken(token);
    }
  } catch {
    errorMsg = errorBody || errorMsg;
  }

  return { success: false, error: errorMsg };
}

export async function handler(req: Request): Promise<Response> {
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

    const token = await getUserFcmToken(payload.user_id);
    if (!token) {
      return new Response(
        JSON.stringify({ success: false, error: "No FCM token found" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!raw) throw new Error("FCM_SERVICE_ACCOUNT not configured");
    const sa: ServiceAccount = JSON.parse(raw);

    const result = await sendFcmNotification(
      sa.project_id,
      token,
      payload.title,
      payload.body,
      payload.data,
    );

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
}

// Start the server (only when run directly, not during tests)
if (import.meta.main) serve(handler);
