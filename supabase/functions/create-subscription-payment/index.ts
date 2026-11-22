import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

async function fetchQrBase64(qrUrl: string, basicAuth: string): Promise<string | null> {
  try {
    let qrRes = await fetch(qrUrl);
    if (!qrRes.ok) {
      qrRes = await fetch(qrUrl, {
        headers: { Authorization: `Basic ${basicAuth}` },
      });
    }
    if (!qrRes.ok) return null;

    const buf = new Uint8Array(await qrRes.arrayBuffer());
    let binary = "";
    for (let i = 0; i < buf.length; i++) {
      binary += String.fromCharCode(buf[i]);
    }
    return btoa(binary);
  } catch (e) {
    console.error("fetchQrBase64 error:", e);
    return null;
  }
}

Deno.serve(async (req) => {
  const reply = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });

  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: cors });
  }

  try {
    if (req.method !== "POST") {
      return reply({ error: "Method not allowed" }, 405);
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return reply({ error: "Unauthorized" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey =
      Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SECRET_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const omiseKey = Deno.env.get("OMISE_SECRET_KEY");

    if (!serviceKey || !omiseKey) {
      console.error("Missing SERVICE_ROLE_KEY or OMISE_SECRET_KEY");
      return reply({ error: "Server payment configuration missing" }, 500);
    }

    const basic = btoa(`${omiseKey}:`);

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });

    const {
      data: { user },
      error: authError,
    } = await userClient.auth.getUser();

    if (authError || !user) {
      return reply({ error: "Invalid session" }, 401);
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("role, account_status")
      .eq("id", user.id)
      .maybeSingle();

    if (profileError) throw profileError;

    if (
      profile?.role !== "technician" ||
      profile?.account_status !== "active"
    ) {
      return reply({ error: "Technician account required" }, 403);
    }

    // หากมีรายการ pending ที่ยังมี QR Code อยู่ ให้ส่งกลับไปแสดงผลต่อทันที
    const { data: existing } = await admin
      .from("payments")
      .select("id, subscription_id, provider_charge_id, qr_image_url, status")
      .eq("technician_id", user.id)
      .eq("status", "pending")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (existing && existing.qr_image_url) {
      const qrBase64 = await fetchQrBase64(existing.qr_image_url, basic);

      return reply({
        success: true,
        payment_id: existing.id,
        subscription_id: existing.subscription_id,
        charge_id: existing.provider_charge_id,
        status: existing.status,
        qr_image_url: existing.qr_image_url,
        qr_base64: qrBase64,
        amount: 250,
        currency: "THB",
      });
    }

    // สร้างรายการ Subscription ใหม่
    const { data: subscription, error: subError } = await admin
      .from("subscriptions")
      .insert({
        technician_id: user.id,
        plan_name: "monthly",
        amount: 250,
        currency: "THB",
        status: "pending",
      })
      .select()
      .single();

    if (subError) throw subError;

    // สร้างรายการ Payment ใหม่
    const { data: payment, error: paymentError } = await admin
      .from("payments")
      .insert({
        subscription_id: subscription.id,
        technician_id: user.id,
        provider: "omise",
        amount: 250,
        currency: "THB",
        status: "pending",
      })
      .select()
      .single();

    if (paymentError) throw paymentError;

    const response = await fetch("https://api.omise.co/charges", {
      method: "POST",
      headers: {
        Authorization: `Basic ${basic}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        amount: "25000",
        currency: "thb",
        "source[type]": "promptpay",
        "metadata[payment_id]": payment.id,
      }),
    });

    const charge = await response.json();

    if (!response.ok || !charge.id) {
      console.error("Omise charge error:", charge);
      await admin
        .from("payments")
        .update({ status: "failed" })
        .eq("id", payment.id);

      await admin
        .from("subscriptions")
        .update({ status: "failed" })
        .eq("id", subscription.id);

      return reply(
        {
          error: charge.message ?? "Payment provider rejected the request",
        },
        502,
      );
    }

    const qrUrl = charge.source?.scannable_code?.image?.download_uri ?? null;
    const qrBase64 = qrUrl ? await fetchQrBase64(qrUrl, basic) : null;

    await admin
      .from("payments")
      .update({
        provider_charge_id: charge.id,
        qr_image_url: qrUrl,
      })
      .eq("id", payment.id);

    return reply({
      success: true,
      payment_id: payment.id,
      subscription_id: subscription.id,
      charge_id: charge.id,
      status: charge.status,
      qr_image_url: qrUrl,
      qr_base64: qrBase64,
      amount: 250,
      currency: "THB",
    });
  } catch (error) {
    console.error("create-subscription-payment:", error);
    return reply({ error: "Unable to create payment" }, 500);
  }
});