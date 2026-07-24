// Supabase Edge Function: Send SMS Hook
// Handles phone OTP delivery.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { extractOtpFromMessage } from "../_shared/utils.ts";

interface SendSmsPayload {
  phone: string;
  message?: string;
  otp?: string;
  type: string;
}
serve(async (req) => {
  try {
    const payload: SendSmsPayload = await req.json();
    const provider = Deno.env.get("SMS_PROVIDER") || "log";

    console.log(`[SMS Hook] Provider: ${provider}`);
    console.log(`[SMS Hook] To: ${payload.phone.substring(0, 5)}***`); // Redact phone in logs
    console.log(`[SMS Hook] Type: ${payload.type}`);

    if (provider === "log") {
  const otp = payload.otp || extractOtpFromMessage(payload.message) || "N/A";
  // FIX (Bug #15): Default to production-safe — never log OTPs unless
  // explicitly running in a development environment.  Previously only
  // checked DENO_DEPLOYMENT_ID, which is absent in some self-hosted
  // Supabase instances, causing OTPs to be logged in plaintext.
  const isDev =
    Deno.env.get("ENVIRONMENT") === "development" ||
    Deno.env.get("SUPABASE_ENV") === "development" ||
    Deno.env.get("DENO_ENV") === "development";
  if (isDev) {
    console.log(`[SMS Hook] [DEV] OTP: ${otp}`);
  }
  return new Response(
        JSON.stringify({
          success: true,
          message: "[DEV MODE] OTP delivery simulated",
        }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    if (provider === "twilio") {
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

      return new Response(
        JSON.stringify({ success: twilioResponse.ok }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    if (provider === "textlocal") {
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
            message: payload.message || `Your verification code is ${payload.otp}`,
          }),
        },
      );

      const textlocalResult = await textlocalResponse.json();
      return new Response(
        JSON.stringify({ success: textlocalResult.status === "success" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: `Unknown SMS provider: ${provider}`,
      }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error(`[SMS Hook] Error:`, error);
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
