import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const json = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { "Content-Type": "application/json" },
    });

  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const body = await req.json();

    if (body.key !== "charge.complete" || !body.data?.id) {
      return json({ received: true });
    }

    const chargeId = String(body.data.id);

    const url = Deno.env.get("SUPABASE_URL")!;
    const secret =
      Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SECRET_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const omiseKey = Deno.env.get("OMISE_SECRET_KEY")!;

    if (!secret || !omiseKey) {
      throw new Error("Server configuration missing");
    }

    const admin = createClient(url, secret, {
      auth: { persistSession: false },
    });

    // Verify charge directly with Omise.
    const verifyResponse = await fetch(
      `https://api.omise.co/charges/${encodeURIComponent(chargeId)}`,
      {
        headers: {
          Authorization: `Basic ${btoa(`${omiseKey}:`)}`,
        },
      },
    );

    if (!verifyResponse.ok) {
      throw new Error("Unable to verify charge");
    }

    const charge = await verifyResponse.json();

    const { data: payment, error: findError } = await admin
      .from("payments")
      .select("*")
      .eq("provider_charge_id", chargeId)
      .maybeSingle();

    if (findError) throw findError;

    if (!payment) {
      return json({ error: "Payment not found" }, 404);
    }

    // Verify the exact amount and currency.
    if (
      charge.amount !== 25000 ||
      charge.currency?.toLowerCase() !== "thb"
    ) {
      throw new Error("Payment amount mismatch");
    }

    // Idempotency: never extend a subscription twice.
    if (payment.status === "successful") {
      return json({ received: true, already_processed: true });
    }

    if (charge.status === "successful") {
      const { error: activationError } = await admin.rpc(
        "confirm_subscription_payment",
        {
          p_payment_id: payment.id,
          p_charge_id: chargeId,
        },
      );

      if (activationError) throw activationError;

      return json({ received: true, activated: true });
    }

    if (["failed", "expired"].includes(charge.status)) {
      await admin.from("payments").update({
        status: charge.status,
        updated_at: new Date().toISOString(),
      }).eq("id", payment.id).eq("status", "pending");

      await admin.from("subscriptions").update({
        status: charge.status,
      }).eq("id", payment.subscription_id)
        .eq("status", "pending");
    }

    return json({ received: true, status: charge.status });
  } catch (error) {
    console.error("omise-webhook:", error);
    return json({ error: "Webhook processing failed" }, 500);
  }
});