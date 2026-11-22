import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PERMANENT_BAN_DURATION = "876000h";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Unauthorized" }, 401);
    }

    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) {
      return json({ error: "Unauthorized" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey =
      Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SECRET_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceKey) {
      console.error("admin-manage-user: missing environment variables");
      return json({ error: "Server configuration missing" }, 500);
    }

    // Verify the actual signed-in user
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });

    const {
      data: { user },
      error: authError,
    } = await userClient.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Invalid session" }, 401);
    }

    // Privileged client stays on the server
    const adminClient = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    // Verify admin role from trusted database record
    const { data: adminProfile, error: adminError } = await adminClient
      .from("profiles")
      .select("role, account_status")
      .eq("id", user.id)
      .maybeSingle();

    if (
      adminError ||
      adminProfile?.role !== "admin" ||
      adminProfile?.account_status !== "active"
    ) {
      return json({ error: "Admin permission required" }, 403);
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return json({ error: "Invalid JSON body" }, 400);
    }

    const targetUserId = String(body.target_user_id ?? "").trim();
    const rawAction = String(body.action ?? "").trim();
    const reason = String(body.reason ?? "").trim();

    if (!UUID_REGEX.test(targetUserId)) {
      return json({ error: "Invalid target user ID" }, 400);
    }

    if (targetUserId === user.id) {
      return json({ error: "Cannot modify your own admin account" }, 400);
    }

    if (!["suspend", "unsuspend", "activate"].includes(rawAction)) {
      return json({ error: "Invalid action" }, 400);
    }

    const isSuspending = rawAction === "suspend";

    if (isSuspending && reason.length < 3) {
      return json(
        { error: "Suspension reason is required (at least 3 characters)" },
        400,
      );
    }

    // Verify target exists and prevent modifying an admin
    const { data: target, error: targetError } = await adminClient
      .from("profiles")
      .select("id, role, account_status")
      .eq("id", targetUserId)
      .maybeSingle();

    if (targetError) {
      throw targetError;
    }

    if (!target) {
      return json({ error: "Member not found" }, 404);
    }

    if (target.role === "admin") {
      return json({ error: "Cannot suspend an admin" }, 403);
    }

    const now = new Date().toISOString();
    const previousStatus = target.account_status;
    const nextStatus = isSuspending ? "suspended" : "active";

    // 1. Update application account status first
    const { error: profileError } = await adminClient
      .from("profiles")
      .update({
        account_status: nextStatus,
        suspended_at: isSuspending ? now : null,
        suspension_reason: isSuspending ? reason : null,
        updated_at: now,
      })
      .eq("id", targetUserId);

    if (profileError) {
      throw profileError;
    }

    // 2. Ban or unban Supabase Auth account
    const { error: authUpdateError } =
      await adminClient.auth.admin.updateUserById(targetUserId, {
        ban_duration: isSuspending ? PERMANENT_BAN_DURATION : "none",
      });

    if (authUpdateError) {
      // Best-effort rollback of profile changes if Auth update fails
      await adminClient
        .from("profiles")
        .update({
          account_status: previousStatus,
          suspended_at: previousStatus === "suspended" ? now : null,
          suspension_reason: previousStatus === "suspended"
            ? reason || "Auth suspension failed"
            : null,
          updated_at: new Date().toISOString(),
        })
        .eq("id", targetUserId);

      return json(
        {
          error: "Unable to update authentication status",
          details: authUpdateError.message,
        },
        500,
      );
    }

    // 3. Record audit log (รองรับทั้ง action ชื่อเดิมและชื่อใหม่ใน details)
    const auditAction = isSuspending
      ? "suspend_member"
      : rawAction === "activate"
      ? "user_activated"
      : "unsuspend_member";

    const { error: auditError } = await adminClient
      .from("admin_audit_logs")
      .insert({
        admin_id: user.id,
        target_user_id: targetUserId,
        action: auditAction,
        details: {
          requested_action: rawAction,
          reason: isSuspending ? reason : null,
          previous_status: previousStatus,
          new_status: nextStatus,
        },
      });

    if (auditError) {
      console.error("admin-manage-user audit log error:", auditError);
      return json(
        {
          success: true,
          action: rawAction,
          target_user_id: targetUserId,
          warning: "Account updated but audit log failed",
        },
        200,
      );
    }

    return json({
      success: true,
      action: rawAction,
      target_user_id: targetUserId,
    });
  } catch (error) {
    console.error("admin-manage-user:", error);
    return json(
      {
        error: error instanceof Error
          ? error.message
          : "Internal server error",
      },
      500,
    );
  }
});