// Supabase Edge Function: Send SMS Hook
// Handles phone OTP delivery.
// - Development mode: Logs OTP code (no real SMS sent)
// - Production mode: Sends SMS via configured provider
//
// Environment variables:
// - SMS_PROVIDER: 'log' (dev), 'twilio', 'textlocal', etc.
// - TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_SERVICE_SID
// - TEXTLOCAL_API_KEY, TEXTLOCAL_SENDER

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

interface SendSmsPayload {
  phone: string;
  message: string;
  type: "sms" | "phone_verify";
  otp?: string;
  /** Message template contains {{ .Code }} placeholder which Supabase replaces */
}

/**
 * Extract the OTP code from the SMS message template.
 * Supabase replaces {{ .Code }} with the actual OTP, so the message
 * will contain the 6-digit code directly.
 */
function extractOtpFromMessage(message: string): string | null {
  const match = message.match(/\b(\d{6})\b/);
  return match ? match[1] : null;
}

serve(async (req) => {
  try {
    const payload: SendSmsPayload = await req.json();
    const provider = Deno.env.get("SMS_PROVIDER") || "log";

    // Try to get OTP from payload or extract from message
    const otp = payload.otp || extractOtpFromMessage(payload.message) || "N/A";

    console.log(`[SMS Hook] Provider: ${provider}`);
    console.log(`[SMS Hook] To: ${payload.phone}`);
    console.log(`[SMS Hook] Type: ${payload.type}`);
    console.log(`[SMS Hook] OTP: ${otp}`);
    console.log(`[SMS Hook] Message: ${payload.message}`);

    if (provider === "log") {
      // DEVELOPMENT MODE: Just log the OTP
      // Check Supabase Dashboard > Edge Functions > send-sms > Logs
      // or Supabase Dashboard > Auth > Logs for the OTP code
      return new Response(
        JSON.stringify({
          success: true,
          message: `[DEV MODE] OTP for ${payload.phone}: ${otp}`,
          _dev_otp: otp,
        }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    if (provider === "twilio") {
      // PRODUCTION: Send via Twilio
      const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
      const authToken = Deno.env.get("TWILIO_AUTH_TOKEN");
      const serviceSid = Deno.env.get("TWILIO_SERVICE_SID");

      if (!accountSid || !authToken || !serviceSid) {
        throw new Error("Twilio credentials not configured");
      }

      const twilioResponse = await fetch(
        `https://verify.twilio.com/v2/Services/${serviceSid}/Verifications`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: new URLSearchParams({
            To: payload.phone,
            Channel: "sms",
          }),
        },
      );

      const twilioResult = await twilioResponse.json();
      console.log(`[SMS Hook] Twilio response:`, twilioResult);

      return new Response(
        JSON.stringify({ success: twilioResponse.ok }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    if (provider === "textlocal") {
      // PRODUCTION: Send via TextLocal (good for Pakistan/India)
      const apiKey = Deno.env.get("TEXTLOCAL_API_KEY");
      const sender = Deno.env.get("TEXTLOCAL_SENDER");

      if (!apiKey) {
        throw new Error("TextLocal credentials not configured");
      }

      const textlocalResponse = await fetch(
        "https://api.textlocal.in/send/",
        {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            apikey: apiKey,
            numbers: payload.phone.replace(/[^0-9]/g, ""),
            sender: sender || "LXSERV",
            message: payload.message,
          }),
        },
      );

      const textlocalResult = await textlocalResponse.json();
      console.log(`[SMS Hook] TextLocal response:`, textlocalResult);

      return new Response(
        JSON.stringify({ success: textlocalResult.status === "success" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    // Unknown provider
    return new Response(
      JSON.stringify({
        success: false,
        error: `Unknown SMS provider: ${provider}`,
      }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error(`[SMS Hook] Error:`, error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
