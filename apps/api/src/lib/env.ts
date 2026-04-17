import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.url(),
  SESSION_SECRET: z.string().min(32),
  GEMINI_API_KEY: z.string().min(1).optional(),
  APP_BASE_URL: z.url().optional(),
});

export function getEnv() {
  return envSchema.parse(process.env);
}
