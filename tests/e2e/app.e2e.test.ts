import request from "supertest";
import { describe, expect, it } from "vitest";
import { createApp } from "../../src/app.js";

describe("appdemo task API", () => {
  it("returns health status", async () => {
    const app = createApp();
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body.status).toBe("ok");
    expect(response.body.service).toBe("appdemo");
  });

  it("creates and lists tasks", async () => {
    const app = createApp();

    const createResponse = await request(app)
      .post("/api/tasks")
      .send({ title: "Ship workflow kernel" });

    expect(createResponse.status).toBe(201);
    expect(createResponse.body.id).toBe(1);
    expect(createResponse.body.done).toBe(false);

    const listResponse = await request(app).get("/api/tasks");
    expect(listResponse.status).toBe(200);
    expect(listResponse.body.count).toBe(1);
    expect(listResponse.body.items[0].title).toBe("Ship workflow kernel");
  });

  it("updates task status", async () => {
    const app = createApp();

    await request(app).post("/api/tasks").send({ title: "Validate appdemo" });
    const patchResponse = await request(app)
      .patch("/api/tasks/1")
      .send({ done: true });

    expect(patchResponse.status).toBe(200);
    expect(patchResponse.body.done).toBe(true);
  });

  it("returns not found when updating unknown task", async () => {
    const app = createApp();
    const response = await request(app).patch("/api/tasks/999").send({ done: true });

    expect(response.status).toBe(404);
    expect(response.body.error).toBe("TASK_NOT_FOUND");
  });
});
