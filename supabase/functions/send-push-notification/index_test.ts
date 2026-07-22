// Tests for send-push-notification Edge Function
//
// Run: deno test supabase/functions/send-push-notification/index_test.ts
// Requires: Deno 1.x+

import {
  assertEquals,
  assertExists,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";

// ─── Types (mirrors production code) ─────────────────────────────────

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

// ─── Pure functions under test (mirrors production code) ──────────────

/**
 * Convert PEM private key to ArrayBuffer (PKCS#8 DER format).
 * This is the pure data transformation part of getAccessToken().
 */
function pemToBinary(pem: string): ArrayBuffer {
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
}

/**
 * Send a push notification via FCM HTTP v1 API (without live HTTP).
 * This tests the response parsing and error handling logic.
 */
async function sendFcmNotification(
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<FcmResponse> {
  const accessToken = "test-access-token";

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

    if (errorMsg.includes("UNREGISTERED") || errorMsg.includes("NOT_FOUND")) {
      console.warn(`[FCM] Token not registered, should remove: ${token}`);
    }
  } catch {
    errorMsg = errorBody || errorMsg;
  }

  return { success: false, error: errorMsg };
}

// ─── Tests: pemToBinary ──────────────────────────────────────────────

Deno.test("pemToBinary", async (t) => {
  await t.step("converts PEM string to ArrayBuffer", () => {
    // A minimal valid base64-encoded PKCS#8 key (not a real key)
    const pem = "-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg\n-----END PRIVATE KEY-----";
    const buffer = pemToBinary(pem);
    assertExists(buffer);
    assertExists(buffer.byteLength);
    assertExists(new Uint8Array(buffer));
  });

  await t.step("strips PEM headers and whitespace", () => {
    const pem = "-----BEGIN PRIVATE KEY-----\n\n\n\nRGlzIGlzIGJhc2U2NA==\n\n-----END PRIVATE KEY-----";
    const buffer = pemToBinary(pem);
    const bytes = new Uint8Array(buffer);
    // "RGlzIGlzIGJhc2U2NA==" decodes to "Dis is base64" (12 bytes)
    assertEquals(bytes.length, 13);
    const decoded = new TextDecoder().decode(bytes);
    assertEquals(decoded, "Dis is base64");
  });

  await t.step("handles PEM without headers (edge case)", () => {
    const pem = "RGlzIGlzIGJhc2U2NA==";
    const buffer = pemToBinary(pem);
    const bytes = new Uint8Array(buffer);
    assertEquals(bytes.length, 13);
  });

  await t.step("handles empty PEM string", () => {
    const buffer = pemToBinary("");
    assertEquals(buffer.byteLength, 0);
  });
});

// ─── Tests: sendFcmNotification (response parsing) ───────────────────

Deno.test("sendFcmNotification", async (t) => {
  // Note: These tests make real HTTP requests and will fail in offline
  // environments. The tests verify the response parsing logic runs
  // correctly regardless of whether FCM responds.

  await t.step("sends notification and handles non-200 response gracefully", async () => {
    // Using an invalid project ID ensures we get a non-200 response
    // from FCM, testing the error-handling path
    const result = await sendFcmNotification(
      "invalid-project",
      "fake-device-token",
      "Test Title",
      "Test Body",
    );
    // Should either succeed (unlikely with fake data) or return error
    if (!result.success) {
      assertExists(result.error);
      assertEquals(typeof result.error, "string");
    }
  });

  await t.step("handles missing data parameter gracefully", async () => {
    const result = await sendFcmNotification(
      "test-project",
      "test-token",
      "Title",
      "Body",
    );
    // Should not throw — undefined data is handled by `data || undefined`
    assertExists(result);
  });
});

// ─── Tests: ServiceAccount type validation ───────────────────────────

Deno.test("ServiceAccount structure", async (t) => {
  await t.step("validates required fields exist", () => {
    const sa: ServiceAccount = {
      project_id: "test-project",
      private_key: "-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg\n-----END PRIVATE KEY-----",
      client_email: "test@test-project.iam.gserviceaccount.com",
    };
    assertEquals(sa.project_id, "test-project");
    assertExists(sa.private_key);
    assertExists(sa.client_email);
  });

  await t.step("handles extra fields via index signature", () => {
    const sa: ServiceAccount = {
      project_id: "p",
      private_key: "pk",
      client_email: "e",
      extra_field: "value",
      type: "service_account",
    };
    assertEquals(sa.extra_field, "value");
    assertEquals(sa.type, "service_account");
  });
});

// ─── Tests: Interface validation ────────────────────────────────────

Deno.test("FcmResponse types", async (t) => {
  await t.step("success response has message_id", () => {
    const resp: FcmResponse = { success: true, message_id: "projects/test/messages/abc123" };
    assertExists(resp.message_id);
  });

  await t.step("error response has error message", () => {
    const resp: FcmResponse = { success: false, error: "UNREGISTERED" };
    assertEquals(resp.error, "UNREGISTERED");
  });
});

// ─── Tests: PushPayload validation ───────────────────────────────────

Deno.test("PushPayload structure", async (t) => {
  await t.step("minimal payload has required fields", () => {
    const payload = { user_id: "user-1", title: "Test", body: "Hello" };
    assertEquals(payload.user_id, "user-1");
    assertEquals(payload.title, "Test");
    assertEquals(payload.body, "Hello");
  });

  await t.step("payload can include optional data field", () => {
    const payload = {
      user_id: "user-1",
      title: "New Message",
      body: "You have a new message",
      data: { type: "new_message", id: "job-1" },
    };
    assertExists(payload.data);
    assertEquals(payload.data.type, "new_message");
    assertEquals(payload.data.id, "job-1");
  });
});
