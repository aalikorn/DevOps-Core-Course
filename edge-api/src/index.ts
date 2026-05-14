/**
 * Cloudflare Workers Edge API
 * Lab 17 - DevOps Core Course
 */

export interface Env {
  // Environment variables (plaintext)
  APP_NAME: string;
  COURSE_NAME: string;
  
  // Secrets (encrypted)
  API_TOKEN: string;
  ADMIN_EMAIL: string;
  
  // KV namespace binding
  SETTINGS: KVNamespace;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    
    // Log incoming request
    console.log("Request received:", {
      path: url.pathname,
      method: request.method,
      colo: request.cf?.colo,
      country: request.cf?.country,
    });

    // Route: Health check
    if (url.pathname === "/health") {
      return Response.json({
        status: "ok",
        timestamp: new Date().toISOString(),
        service: "edge-api",
      });
    }

    // Route: Main endpoint with app info
    if (url.pathname === "/") {
      return Response.json({
        app: env.APP_NAME,
        course: env.COURSE_NAME,
        message: "Hello from Cloudflare Workers Edge Network",
        timestamp: new Date().toISOString(),
        version: "1.0.0",
        endpoints: [
          "/",
          "/health",
          "/edge",
          "/counter",
          "/config",
        ],
      });
    }

    // Route: Edge metadata
    if (url.pathname === "/edge") {
      return Response.json({
        colo: request.cf?.colo,
        country: request.cf?.country,
        city: request.cf?.city,
        region: request.cf?.region,
        asn: request.cf?.asn,
        httpProtocol: request.cf?.httpProtocol,
        tlsVersion: request.cf?.tlsVersion,
        timezone: request.cf?.timezone,
        latitude: request.cf?.latitude,
        longitude: request.cf?.longitude,
        requestTimestamp: new Date().toISOString(),
      });
    }

    // Route: KV-backed counter (persistence demo)
    if (url.pathname === "/counter") {
      try {
        const raw = await env.SETTINGS.get("visits");
        const visits = Number(raw ?? "0") + 1;
        await env.SETTINGS.put("visits", String(visits));
        
        return Response.json({
          visits,
          message: "Counter incremented successfully",
          persistent: true,
          storage: "Workers KV",
        });
      } catch (error) {
        console.error("Counter error:", error);
        return Response.json(
          { error: "Failed to update counter" },
          { status: 500 }
        );
      }
    }

    // Route: Configuration info (demonstrates env vars and secrets usage)
    if (url.pathname === "/config") {
      return Response.json({
        app: env.APP_NAME,
        course: env.COURSE_NAME,
        // Show that secrets exist without exposing values
        hasApiToken: !!env.API_TOKEN,
        hasAdminEmail: !!env.ADMIN_EMAIL,
        adminEmailDomain: env.ADMIN_EMAIL ? env.ADMIN_EMAIL.split("@")[1] : null,
        message: "Configuration loaded from environment",
      });
    }

    // 404 for unknown routes
    return new Response("Not Found", { status: 404 });
  },
};
