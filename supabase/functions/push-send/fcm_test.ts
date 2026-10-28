import { assertEquals } from "jsr:@std/assert@1";
import { messageFor } from "./fcm.ts";

Deno.test("copy is fixed and the liker stays hidden", () => {
  assertEquals(messageFor("liked", "x"), { notification: { title: "Someone likes you", body: "A new like is waiting in Likes You." }, data: { kind: "liked" } });
  assertEquals(messageFor("message", "acc-1").data, { kind: "message", account_id: "acc-1" });
  assertEquals(messageFor("matched", "acc-1").notification.title, "It's a match");
  assertEquals(messageFor("matched", "acc-1").notification.body, "Someone you crossed paths with likes you back.");
  assertEquals(messageFor("message", "acc-1").notification, { title: "New message", body: "Someone you matched with wrote to you." });
});
