import express from "express";
import { z } from "zod";

const createTaskSchema = z.object({
  title: z.string().trim().min(1).max(120),
});

const updateTaskSchema = z
  .object({
    title: z.string().trim().min(1).max(120).optional(),
    done: z.boolean().optional(),
  })
  .refine(
    (payload) => payload.title !== undefined || payload.done !== undefined,
    "Provide at least one field to update",
  );

interface Task {
  id: number;
  title: string;
  done: boolean;
  createdAt: string;
  updatedAt: string;
}

export function createApp() {
  const app = express();
  app.use(express.json());

  let nextId = 1;
  const tasks: Task[] = [];

  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      service: "appdemo",
      timestamp: new Date().toISOString(),
    });
  });

  app.get("/api/tasks", (_req, res) => {
    res.json({
      count: tasks.length,
      items: tasks,
    });
  });

  app.post("/api/tasks", (req, res) => {
    const parsed = createTaskSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: "INVALID_REQUEST",
        details: parsed.error.flatten(),
      });
    }

    const now = new Date().toISOString();
    const task: Task = {
      id: nextId,
      title: parsed.data.title,
      done: false,
      createdAt: now,
      updatedAt: now,
    };
    nextId += 1;
    tasks.push(task);

    return res.status(201).json(task);
  });

  app.patch("/api/tasks/:id", (req, res) => {
    const taskId = Number(req.params.id);
    if (!Number.isInteger(taskId) || taskId <= 0) {
      return res.status(400).json({ error: "INVALID_TASK_ID" });
    }

    const parsed = updateTaskSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: "INVALID_REQUEST",
        details: parsed.error.flatten(),
      });
    }

    const task = tasks.find((item) => item.id === taskId);
    if (!task) {
      return res.status(404).json({ error: "TASK_NOT_FOUND" });
    }

    if (parsed.data.title !== undefined) {
      task.title = parsed.data.title;
    }
    if (parsed.data.done !== undefined) {
      task.done = parsed.data.done;
    }
    task.updatedAt = new Date().toISOString();

    return res.json(task);
  });

  return app;
}
