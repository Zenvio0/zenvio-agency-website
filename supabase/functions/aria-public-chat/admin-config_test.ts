import { assertEquals } from "jsr:@std/assert@1";
import { applyAdminLocks } from "./admin-config.ts";

Deno.test("locked admin values override owner settings", () => {
  assertEquals(
    applyAdminLocks({ tone: "casual", owner_enabled: true }, { tone: "formal", owner_enabled: false }, ["tone", "owner_enabled"]),
    { tone: "formal", owner_enabled: false },
  );
});

Deno.test("unlocked admin values do not override owner settings", () => {
  assertEquals(
    applyAdminLocks({ tone: "casual", greeting: "Hi" }, { tone: "formal", greeting: "Welcome" }, ["tone"]),
    { tone: "formal", greeting: "Hi" },
  );
});

Deno.test("unknown locked fields and malformed locks are ignored safely", () => {
  assertEquals(applyAdminLocks({ tone: "casual" }, { tone: "formal" }, ["missing"]), { tone: "casual" });
  assertEquals(applyAdminLocks({ tone: "casual" }, { tone: "formal" }, "tone"), { tone: "casual" });
});

Deno.test("admin values cannot inject keys unless explicitly locked", () => {
  assertEquals(applyAdminLocks({ owner_enabled: true }, { owner_enabled: false, arbitrary: "x" }, []), { owner_enabled: true });
});
