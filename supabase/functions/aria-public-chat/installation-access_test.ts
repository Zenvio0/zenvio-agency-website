import { assertEquals } from "jsr:@std/assert@1";
import { installationAccessError } from "./installation-access.ts";

Deno.test("enabled installation with enabled owner and admin is available", () => {
  assertEquals(installationAccessError({ enabled: true, revoked_at: null }, { globally_enabled: true }, { owner_enabled: true }), null);
});
Deno.test("missing, disabled, and revoked installations are unavailable", () => {
  assertEquals(installationAccessError(null, null, null), "This assistant is currently unavailable");
  assertEquals(installationAccessError({ enabled: false }, null, null), "This assistant is currently unavailable");
  assertEquals(installationAccessError({ enabled: true, revoked_at: "2026-01-01T00:00:00Z" }, null, null), "This assistant is currently unavailable");
});
Deno.test("Super Admin global disable overrides owner preference", () => {
  assertEquals(installationAccessError({ enabled: true }, { globally_enabled: false }, { owner_enabled: true }), "This assistant is currently unavailable");
});
Deno.test("owner disable blocks otherwise active installation", () => {
  assertEquals(installationAccessError({ enabled: true }, { globally_enabled: true }, { owner_enabled: false }), "This assistant has been disabled by the website owner");
});
Deno.test("missing optional config defaults to available when installation is active", () => {
  assertEquals(installationAccessError({ enabled: true }, null, null), null);
});
