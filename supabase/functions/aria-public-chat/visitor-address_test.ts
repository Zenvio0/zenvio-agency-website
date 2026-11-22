import { assertEquals } from "jsr:@std/assert@1";
import { trustedVisitorAddress } from "./visitor-address.ts";

Deno.test("uses Cloudflare's connection address", () => {
  const headers = new Headers({ "cf-connecting-ip": "203.0.113.10", "x-forwarded-for": "198.51.100.2" });
  assertEquals(trustedVisitorAddress(headers), "203.0.113.10");
});
Deno.test("does not trust client-controlled forwarded-for when Cloudflare address is absent", () => {
  const headers = new Headers({ "x-forwarded-for": "198.51.100.2" });
  assertEquals(trustedVisitorAddress(headers), "unknown");
});
Deno.test("trims Cloudflare address and safely handles missing headers", () => {
  assertEquals(trustedVisitorAddress(new Headers({ "cf-connecting-ip": " 203.0.113.4 " })), "203.0.113.4");
  assertEquals(trustedVisitorAddress(new Headers()), "unknown");
});
