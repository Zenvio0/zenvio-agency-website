import { assertEquals } from "jsr:@std/assert@1";
import { disabledCapability } from "./capabilities.ts";

Deno.test("contact and booking requests are blocked when contact is disabled", () => {
  const config = { contact: false, services: true, recommendations: true };
  for (const prompt of ["What is your email?", "Can I book an appointment?", "Please call me"]) {
    assertEquals(disabledCapability(prompt, config)?.includes("contact or booking"), true);
  }
});

Deno.test("recommendation requests are blocked only when recommendations are disabled", () => {
  const config = { contact: true, services: true, recommendations: false };
  assertEquals(disabledCapability("Which option is best for me?", config)?.includes("recommendations"), true);
  assertEquals(disabledCapability("Where are you located?", config), null);
});

Deno.test("service and product questions are blocked when services are disabled", () => {
  const config = { contact: true, services: false, recommendations: true };
  assertEquals(disabledCapability("What services do you offer?", config)?.includes("service or product"), true);
  assertEquals(disabledCapability("How can I contact you?", config), null);
});

Deno.test("enabled capabilities do not block matching requests", () => {
  const config = { contact: true, services: true, recommendations: true };
  assertEquals(disabledCapability("What is your price and email?", config), null);
});

Deno.test("unrelated questions are not blocked", () => {
  const config = { contact: false, services: false, recommendations: false };
  assertEquals(disabledCapability("Tell me about your company's history.", config), null);
});
