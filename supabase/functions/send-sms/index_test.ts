// Tests for send-sms Edge Function
//
// Run: deno test supabase/functions/send-sms/index_test.ts
// Requires: Deno 1.x+

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { extractOtpFromMessage } from "../_shared/utils.ts";

// ─── Tests ────────────────────────────────────────────────────────────

Deno.test("extractOtpFromMessage", async (t) => {
  await t.step("extracts 6-digit code from message", () => {
    const result = extractOtpFromMessage("Your OTP is 123456");
    assertEquals(result, "123456");
  });

  await t.step("extracts code with surrounding punctuation", () => {
    const result = extractOtpFromMessage("Code: 987654. Please verify.");
    assertEquals(result, "987654");
  });

  await t.step("returns null when no 6-digit code present", () => {
    const result = extractOtpFromMessage("Your OTP is 12345"); // 5 digits
    assertEquals(result, null);
  });

  await t.step("returns null for message with 7-digit number", () => {
    const result = extractOtpFromMessage("Code 1234567");
    assertEquals(result, null);
  });

  await t.step("returns null for empty message", () => {
    const result = extractOtpFromMessage("");
    assertEquals(result, null);
  });

  await t.step("extracts first 6-digit code when multiple exist", () => {
    const result = extractOtpFromMessage("First: 111111, Second: 222222");
    assertEquals(result, "111111");
  });

  await t.step("handles code at start of string", () => {
    const result = extractOtpFromMessage("123456 is your code");
    assertEquals(result, "123456");
  });

  await t.step("handles code at end of string", () => {
    const result = extractOtpFromMessage("Your code is 123456");
    assertEquals(result, "123456");
  });

  await t.step("returns null for message with only letters", () => {
    const result = extractOtpFromMessage("No numbers here");
    assertEquals(result, null);
  });

  await t.step("handles codes with spaces inside (should not match)", () => {
    // 6 digits with a space won't match \b(\d{6})\b since the space
    // breaks the word boundary pattern
    const result = extractOtpFromMessage("Code: 123 456");
    assertEquals(result, null);
  });
});

Deno.test("extractOtpFromMessage — edge cases", async (t) => {
  await t.step("handles very long message with code at end", () => {
    const long = "A".repeat(1000) + " 000000";
    const result = extractOtpFromMessage(long);
    assertEquals(result, "000000");
  });

  await t.step("code adjacent to non-digit characters", () => {
    const result = extractOtpFromMessage("OTP=123456!");
    assertEquals(result, "123456");
  });

  await t.step("only numeric string of exactly 6 digits", () => {
    const result = extractOtpFromMessage("654321");
    assertEquals(result, "654321");
  });
});
